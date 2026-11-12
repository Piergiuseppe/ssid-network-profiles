import Foundation

struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var ssid: String
    var ip: String
    var subnet: String
    var gateway: String
    var dns: [String]
}

struct StoreData: Codable {
    var profiles: [Profile] = []
    var active: [String: UUID] = [:]
    var autoApply = true
}

struct LiveConfig: Equatable {
    var manual = false
    var ip = ""
    var subnet = ""
    var gateway = ""
    var dns: [String] = []

    func matches(_ profile: Profile) -> Bool {
        manual && ip == profile.ip && subnet == profile.subnet && gateway == profile.gateway && dns == profile.dns
    }
}

enum IPv4 {
    static func isValid(_ text: String) -> Bool {
        var address = in_addr()
        return text.split(separator: ".").count == 4 && inet_pton(AF_INET, text, &address) == 1
    }
}
