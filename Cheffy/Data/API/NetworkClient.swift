import Foundation
import Network
import os.log

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case noInternetConnection
    case timeout
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)
    case clientError(Int)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .clientError(let code):
            return "Client error: \(code)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Network Request
struct NetworkRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval
    
    init(
        url: URL,
        method: HTTPMethod = .GET,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30.0
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Network Response
struct NetworkResponse<T: Codable> {
    let data: T
    let statusCode: Int
    let headers: [String: String]
    let isFromCache: Bool
}

// MARK: - NetworkClient Protocol
protocol NetworkClient {
    func request<T: Codable>(_ request: NetworkRequest) async throws -> NetworkResponse<T>
    func requestWithRetry<T: Codable>(_ request: NetworkRequest, maxRetries: Int) async throws -> NetworkResponse<T>
    func isConnected() -> Bool
    func clearCache()
}

// MARK: - NetworkClient Implementation
class NetworkClientImpl: NetworkClient {
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var isConnectedStatus: Bool = false
    private let cache = NSCache<NSString, CachedResponse>()
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        self.session = URLSession(configuration: config)
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "NetworkMonitor")
        
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnectedStatus = path.status == .satisfied
                os_log("Network connectivity changed: %{public}@", log: .default, type: .info, path.status == .satisfied ? "Connected" : "Disconnected")
            }
        }
        monitor.start(queue: queue)
    }
    
    func isConnected() -> Bool {
        return isConnectedStatus
    }
    
    // MARK: - Main Request Method
    func request<T: Codable>(_ request: NetworkRequest) async throws -> NetworkResponse<T> {
        // Check connectivity first
        guard isConnected() else {
            os_log("Network request failed - no internet connection", log: .default, type: .error)
            throw NetworkError.noInternetConnection
        }
        
        // Check cache first for GET requests
        if request.method == .GET {
            if let cachedResponse = getCachedResponse(for: request.url) {
                if let decodedData = try? JSONDecoder().decode(T.self, from: cachedResponse.data) {
                    os_log("Returning cached response for: %{public}@", log: .default, type: .info, request.url.absoluteString)
                    return NetworkResponse(
                        data: decodedData,
                        statusCode: cachedResponse.statusCode,
                        headers: cachedResponse.headers,
                        isFromCache: true
                    )
                }
            }
        }
        
        // Create URLRequest
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout
        
        // Add headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body
        if let body = request.body {
            urlRequest.httpBody = body
        }
        
        // Make request
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                os_log("Invalid response type for: %{public}@", log: .default, type: .error, request.url.absoluteString)
                throw NetworkError.invalidResponse
            }
            
            // Log response
            os_log("HTTP Status: %{public}d for %{public}@", log: .default, type: .info, httpResponse.statusCode, request.url.absoluteString)
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - try to decode
                do {
                    let decodedData = try JSONDecoder().decode(T.self, from: data)
                    
                    // Cache successful GET responses
                    if request.method == .GET {
                        cacheResponse(data: data, for: request.url, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields as? [String: String] ?? [:])
                    }
                    
                    return NetworkResponse(
                        data: decodedData,
                        statusCode: httpResponse.statusCode,
                        headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                        isFromCache: false
                    )
                } catch {
                    os_log("Decoding error for %{public}@: %{public}@", log: .default, type: .error, request.url.absoluteString, error.localizedDescription)
                    throw NetworkError.decodingError(error)
                }
                
            case 400...499:
                os_log("Client error %{public}d for %{public}@", log: .default, type: .error, httpResponse.statusCode, request.url.absoluteString)
                throw NetworkError.clientError(httpResponse.statusCode)
                
            case 500...599:
                os_log("Server error %{public}d for %{public}@", log: .default, type: .error, httpResponse.statusCode, request.url.absoluteString)
                throw NetworkError.serverError(httpResponse.statusCode)
                
            default:
                os_log("Unknown status code %{public}d for %{public}@", log: .default, type: .error, httpResponse.statusCode, request.url.absoluteString)
                throw NetworkError.unknown(NetworkError.invalidResponse)
            }
            
        } catch let error as NetworkError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                os_log("Request timeout for: %{public}@", log: .default, type: .error, request.url.absoluteString)
                throw NetworkError.timeout
            } else {
                os_log("Network error for %{public}@: %{public}@", log: .default, type: .error, request.url.absoluteString, error.localizedDescription)
                throw NetworkError.unknown(error)
            }
        }
    }
    
    // MARK: - Retry Logic
    func requestWithRetry<T: Codable>(_ request: NetworkRequest, maxRetries: Int = 3) async throws -> NetworkResponse<T> {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await self.request(request)
            } catch {
                lastError = error
                
                // Don't retry certain errors
                if let networkError = error as? NetworkError {
                    switch networkError {
                    case .noInternetConnection, .clientError, .decodingError:
                        throw networkError
                    default:
                        break
                    }
                }
                
                // If this is the last attempt, throw the error
                if attempt == maxRetries {
                    os_log("Request failed after %{public}d attempts for: %{public}@", log: .default, type: .error, maxRetries + 1, request.url.absoluteString)
                    throw error
                }
                
                // Wait before retrying (exponential backoff)
                let delay = TimeInterval(pow(2.0, Double(attempt))) * 0.5
                os_log("Retrying request in %{public}f seconds (attempt %{public}d/%{public}d) for: %{public}@", log: .default, type: .info, delay, attempt + 1, maxRetries + 1, request.url.absoluteString)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NetworkError.unknown(NetworkError.invalidResponse)
    }
    
    // MARK: - Caching
    private func cacheResponse(data: Data, for url: URL, statusCode: Int, headers: [String: String]) {
        let cachedResponse = CachedResponse(
            data: data,
            statusCode: statusCode,
            headers: headers,
            timestamp: Date()
        )
        cache.setObject(cachedResponse, forKey: url.absoluteString as NSString)
        os_log("Cached response for: %{public}@", log: .default, type: .debug, url.absoluteString)
    }
    
    private func getCachedResponse(for url: URL) -> CachedResponse? {
        guard let cachedResponse = cache.object(forKey: url.absoluteString as NSString) else {
            return nil
        }
        
        // Check if cache is still valid (5 minutes)
        let cacheAge = Date().timeIntervalSince(cachedResponse.timestamp)
        if cacheAge > 300 { // 5 minutes
            cache.removeObject(forKey: url.absoluteString as NSString)
            os_log("Cache expired for: %{public}@", log: .default, type: .debug, url.absoluteString)
            return nil
        }
        
        return cachedResponse
    }
    
    func clearCache() {
        cache.removeAllObjects()
        os_log("Network cache cleared", log: .default, type: .info)
    }
}

// MARK: - Cached Response Model
class CachedResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
    let timestamp: Date
    
    init(data: Data, statusCode: Int, headers: [String: String], timestamp: Date) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.timestamp = timestamp
    }
}

// MARK: - Network Connectivity Monitor
class NetworkConnectivityMonitor: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var connectionType: String = "Unknown"
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkConnectivityMonitor")
    
    init() {
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = "WiFi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = "Cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = "Ethernet"
                } else {
                    self?.connectionType = "Unknown"
                }
                
                os_log("Network connectivity: %{public}@ (%{public}@)", log: .default, type: .info, path.status == .satisfied ? "Connected" : "Disconnected", self?.connectionType ?? "Unknown")
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
} 