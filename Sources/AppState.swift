import AppKit
import CoreLocation
import CoreWLAN
import ServiceManagement

@MainActor
final class AppState: NSObject, ObservableObject {
    @Published private(set) var data: StoreData
    @Published private(set) var ssid: String?
    @Published private(set) var live = LiveConfig()
    @Published private(set) var locationAuthorized = false
    @Published private(set) var lastError: String?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let store = ProfileStore()
    private let locationManager = CLLocationManager()
    private let wifiClient = CWWiFiClient.shared()
    private var pendingRefresh: Task<Void, Never>?

    override init() {
        data = store.load()
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        wifiClient.delegate = self
        try? wifiClient.startMonitoringEvent(with: .ssidDidChange)
        try? wifiClient.startMonitoringEvent(with: .linkDidChange)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        scheduleRefresh(after: 0)
    }

    var activeProfile: Profile? {
        guard let ssid, let id = data.active[ssid] else { return nil }
        return data.profiles.first { $0.id == id }
    }

    var currentProfiles: [Profile] {
        data.profiles.filter { $0.ssid == ssid }
    }

    var otherNetworks: [(ssid: String, profiles: [Profile])] {
        Dictionary(grouping: data.profiles.filter { $0.ssid != ssid }, by: \.ssid)
            .map { ($0.key, $0.value) }
            .sorted { $0.ssid.localizedCaseInsensitiveCompare($1.ssid) == .orderedAscending }
    }

    func isActive(_ profile: Profile) -> Bool {
        data.active[profile.ssid] == profile.id
    }

    func activate(_ profile: Profile) {
        data.active[profile.ssid] = profile.id
        persist()
        if profile.ssid == ssid { scheduleRefresh(after: 0, force: true) }
    }

    func useDHCP() {
        guard let ssid else { return }
        data.active[ssid] = nil
        persist()
        scheduleRefresh(after: 0, force: true)
    }

    func save(_ profile: Profile) {
        if let index = data.profiles.firstIndex(where: { $0.id == profile.id }) {
            let previous = data.profiles[index]
            if previous.ssid != profile.ssid, data.active[previous.ssid] == profile.id {
                data.active[previous.ssid] = nil
            }
            data.profiles[index] = profile
        } else {
            data.profiles.append(profile)
            if data.active[profile.ssid] == nil { data.active[profile.ssid] = profile.id }
        }
        persist()
        if profile.ssid == ssid, isActive(profile) { scheduleRefresh(after: 0, force: true) }
    }

    func delete(_ profile: Profile) {
        let wasActive = isActive(profile)
        data.profiles.removeAll { $0.id == profile.id }
        if wasActive { data.active[profile.ssid] = nil }
        persist()
        if wasActive, profile.ssid == ssid { scheduleRefresh(after: 0, force: true) }
    }

    func setAutoApply(_ enabled: Bool) {
        data.autoApply = enabled
        persist()
        if enabled { scheduleRefresh(after: 0) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    func scheduleRefresh(after seconds: Double, force: Bool = false) {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.refresh(force: force)
        }
    }

    private func persist() {
        store.save(data)
    }

    private func refresh(force: Bool) async {
        let shouldApply = force || data.autoApply
        let profiles = data.profiles
        let active = data.active

        let result = await Task.detached { () -> (String?, LiveConfig, String?) in
            let service = NetworkService.serviceName()
            let ssid = NetworkService.currentSSID()
            var live = NetworkService.liveConfig(service: service)
            guard shouldApply, let ssid else { return (ssid, live, nil) }
            let profile = active[ssid].flatMap { id in profiles.first { $0.id == id } }
            do {
                if let profile, !live.matches(profile) {
                    try NetworkService.apply(profile, service: service)
                    live = NetworkService.liveConfig(service: service)
                } else if profile == nil, live.manual {
                    try NetworkService.applyDHCP(service: service)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    live = NetworkService.liveConfig(service: service)
                }
                return (ssid, live, nil)
            } catch {
                return (ssid, live, error.localizedDescription)
            }
        }.value

        ssid = result.0
        live = result.1
        lastError = result.2
    }

    @objc private func systemDidWake() {
        scheduleRefresh(after: 4)
    }
}

extension AppState: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let authorized = status != .notDetermined && status != .denied && status != .restricted
        Task { @MainActor in
            self.locationAuthorized = authorized
            self.scheduleRefresh(after: 0)
        }
    }
}

extension AppState: CWEventDelegate {
    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in self.scheduleRefresh(after: 2) }
    }

    nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in self.scheduleRefresh(after: 2) }
    }
}
