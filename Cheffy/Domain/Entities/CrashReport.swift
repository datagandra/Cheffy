import Foundation
import UIKit
import CloudKit

struct CrashReport: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let appVersion: String
    let deviceInfo: DeviceInfo
    let errorMessage: String
    let stackTrace: String
    let severity: CrashSeverity
    let isUploaded: Bool
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        appVersion: String,
        deviceInfo: DeviceInfo,
        errorMessage: String,
        stackTrace: String,
        severity: CrashSeverity = .medium,
        isUploaded: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.deviceInfo = deviceInfo
        self.errorMessage = errorMessage
        self.stackTrace = stackTrace
        self.severity = severity
        self.isUploaded = isUploaded
    }
}

struct DeviceInfo: Codable {
    let deviceModel: String
    let systemVersion: String
    let appVersion: String
    let buildNumber: String
    let freeDiskSpace: Int64
    let totalDiskSpace: Int64
    let memoryUsage: Int64
    
    init() {
        let device = UIDevice.current
        self.deviceModel = device.model
        self.systemVersion = device.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // Get disk space info
        let fileManager = FileManager.default
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            self.freeDiskSpace = attrs[.systemFreeSize] as? Int64 ?? 0
            self.totalDiskSpace = attrs[.systemSize] as? Int64 ?? 0
        } else {
            self.freeDiskSpace = 0
            self.totalDiskSpace = 0
        }
        
        // Get memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) { intPtr in
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         intPtr,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            self.memoryUsage = Int64(info.resident_size)
        } else {
            self.memoryUsage = 0
        }
    }
}

enum CrashSeverity: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var icon: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - CloudKit Integration
extension CrashReport {
    init?(from record: CKRecord) {
        guard let timestamp = record["timestamp"] as? Date,
              let appVersion = record["appVersion"] as? String,
              let errorMessage = record["errorMessage"] as? String,
              let stackTrace = record["stackTrace"] as? String,
              let severityRaw = record["severity"] as? String,
              let severity = CrashSeverity(rawValue: severityRaw) else {
            return nil
        }
        
        let deviceInfoData = record["deviceInfo"] as? Data
        let deviceInfo = deviceInfoData.flatMap { try? JSONDecoder().decode(DeviceInfo.self, from: $0) } ?? DeviceInfo()
        
        self.id = record.recordID.recordName
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.deviceInfo = deviceInfo
        self.errorMessage = errorMessage
        self.stackTrace = stackTrace
        self.severity = severity
        self.isUploaded = true
    }
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "CrashReport")
        record["timestamp"] = timestamp
        record["appVersion"] = appVersion
        record["deviceInfo"] = try? JSONEncoder().encode(deviceInfo)
        record["errorMessage"] = errorMessage
        record["stackTrace"] = stackTrace
        record["severity"] = severity.rawValue
        return record
    }
}
