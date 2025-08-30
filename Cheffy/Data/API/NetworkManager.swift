import Foundation
import Combine
import Network

// MARK: - Network Manager
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkManager")
    private let errorReporting = ErrorReporting.shared
    
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType = .other
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: config)
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type ?? .other
                
                if path.status == .satisfied {
                    self?.errorReporting.reportWarning("Network connection restored", context: "NetworkManager")
                } else {
                    self?.errorReporting.reportWarning("Network connection lost", context: "NetworkManager")
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    // MARK: - Request Methods
    
    func performRequest<T: Codable>(
        _ request: APIRequest,
        retryCount: Int = 3,
        retryDelay: TimeInterval = 2.0
    ) async throws -> T {
        
        guard isConnected else {
            throw NetworkError.noConnection
        }
        
        var lastError: Error?
        var currentRetryDelay = retryDelay
        
        for attempt in 1...retryCount {
            do {
                return try await performSingleRequest(request)
            } catch {
                lastError = error
                
                if attempt < retryCount {
                    // Log retry attempt
                    errorReporting.reportWarning(
                        "Network request failed, retrying... (attempt \(attempt)/\(retryCount))",
                        context: "NetworkManager"
                    )
                    
                    // Wait before retry
                    try await Task.sleep(nanoseconds: UInt64(currentRetryDelay * 1_000_000_000))
                    
                    // Increase delay for next retry (exponential backoff)
                    currentRetryDelay *= 1.5
                }
            }
        }
        
        // All retries failed
        errorReporting.reportError(
            lastError ?? NetworkError.unknown,
            context: "NetworkManager - All retries failed",
            severity: .high
        )
        
        throw lastError ?? NetworkError.unknown
    }
    
    private func performSingleRequest<T: Codable>(_ request: APIRequest) async throws -> T {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpBody = request.body
        
        // Add default headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Cheffy/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Log request details
        errorReporting.reportWarning(
            "Network request: \(request.method.rawValue) \(request.url.absoluteString) - Status: \(httpResponse.statusCode)",
            context: "NetworkManager"
        )
        
        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            return try decodeResponse(data)
        case 400:
            throw NetworkError.badRequest(try decodeErrorResponse(data))
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 429:
            throw NetworkError.rateLimited
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Response Decoding
    
    private func decodeResponse<T: Codable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            errorReporting.reportError(
                error,
                context: "NetworkManager - JSON Decoding",
                severity: .medium
            )
            throw NetworkError.decodingError(error)
        }
    }
    
    private func decodeErrorResponse(_ data: Data) throws -> String {
        do {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            return errorResponse.message
        } catch {
            return String(data: data, encoding: .utf8) ?? "Unknown error"
        }
    }
    
    // MARK: - Upload Methods
    
    func uploadImage(_ imageData: Data, to endpoint: String) async throws -> String {
        guard isConnected else {
            throw NetworkError.noConnection
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.imageUrl
    }
    
    // MARK: - Download Methods
    
    func downloadFile(from url: URL, to destination: URL) async throws -> URL {
        guard isConnected else {
            throw NetworkError.noConnection
        }
        
        let (tempURL, response) = try await session.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        // Move file to destination
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        session.configuration.urlCache?.removeAllCachedResponses()
    }
    
    // MARK: - Network Diagnostics
    
    func getNetworkDiagnostics() -> NetworkDiagnostics {
        return NetworkDiagnostics(
            isConnected: isConnected,
            connectionType: connectionType,
            availableInterfaces: monitor.currentPath.availableInterfaces.map { $0.type },
            isExpensive: monitor.currentPath.isExpensive,
            isConstrained: monitor.currentPath.isConstrained
        )
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case noConnection
    case invalidResponse
    case badRequest(String)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case decodingError(Error)
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limit exceeded"
        case .serverError(let code):
            return "Server error: \(code)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .unknown:
            return "Unknown network error"
        }
    }
}

// MARK: - Supporting Types

struct ErrorResponse: Codable {
    let message: String
    let code: Int?
}

struct UploadResponse: Codable {
    let imageUrl: String
    let success: Bool
}

struct NetworkDiagnostics {
    let isConnected: Bool
    let connectionType: NWInterface.InterfaceType
    let availableInterfaces: [NWInterface.InterfaceType]
    let isExpensive: Bool
    let isConstrained: Bool
}

// MARK: - Network Manager Extensions

extension NetworkManager: NetworkServiceProtocol {
    func performRequest<T: Codable>(_ request: APIRequest) async throws -> T {
        return try await performRequest(request)
    }
    
    func uploadImage(_ imageData: Data) async throws -> String {
        // This would be configured with your actual upload endpoint
        return try await uploadImage(imageData, to: "https://api.example.com/upload")
    }
} 