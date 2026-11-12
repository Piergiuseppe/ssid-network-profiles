import CoreWLAN
import Foundation

struct NetworkError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum NetworkService {
    private static let tool = "/usr/sbin/networksetup"

    static func currentSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }

    static func serviceName() -> String {
        let device = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
        let lines = run(["-listnetworkserviceorder"]).output.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() where line.hasSuffix("Device: \(device))") && index > 0 {
            let title = lines[index - 1]
            if let close = title.firstIndex(of: ")") {
                return title[title.index(after: close)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return "Wi-Fi"
    }

    static func liveConfig(service: String) -> LiveConfig {
        var config = LiveConfig()
        let info = run(["-getinfo", service]).output.components(separatedBy: "\n")
        config.manual = info.first?.contains("Manual") ?? false
        for line in info {
            if let value = value(of: "IP address", in: line) { config.ip = value }
            if let value = value(of: "Subnet mask", in: line) { config.subnet = value }
            if let value = value(of: "Router", in: line) { config.gateway = value }
        }
        config.dns = run(["-getdnsservers", service]).output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter(IPv4.isValid)
        return config
    }

    static func apply(_ profile: Profile, service: String) throws {
        try check(run(["-setmanual", service, profile.ip, profile.subnet, profile.gateway]))
        try check(run(["-setdnsservers", service] + (profile.dns.isEmpty ? ["Empty"] : profile.dns)))
    }

    static func applyDHCP(service: String) throws {
        try check(run(["-setdhcp", service]))
        try check(run(["-setdnsservers", service, "Empty"]))
    }

    private static func value(of key: String, in line: String) -> String? {
        let prefix = key + ": "
        guard line.hasPrefix(prefix) else { return nil }
        let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        return value == "none" ? nil : value
    }

    private static func check(_ result: (status: Int32, output: String)) throws {
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.status != 0 || output.contains("Error") || output.contains("requires") {
            throw NetworkError(message: output.isEmpty ? "\(String(localized: "networksetup failed")) (\(result.status))" : output)
        }
    }

    private static func run(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let raw = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: raw, encoding: .utf8) ?? "")
    }
}
