import Foundation

struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var ssid: String
    var ip: String
    var subnet: String
    var gateway: String
    var dns: [String]

    var isValid: Bool {
        !name.isEmpty && !ssid.isEmpty
            && [ip, subnet, gateway].allSatisfy(IPv4.isValid)
            && dns.allSatisfy(IPv4.isValid)
    }
}

struct StoreData: Codable {
    var profiles: [Profile] = []
    var active: [String: UUID] = [:]
    var autoApply = true

    mutating func merge(_ other: StoreData) {
        for profile in other.profiles where profile.isValid {
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }
        }
        for (ssid, id) in other.active where profiles.contains(where: { $0.id == id && $0.ssid == ssid }) {
            active[ssid] = id
        }
    }
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
