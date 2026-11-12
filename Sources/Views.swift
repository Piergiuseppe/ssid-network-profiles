import SwiftUI

@main
struct WiFiProfiliApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(state)
        } label: {
            Image(systemName: state.live.manual ? "wifi.router.fill" : "wifi.router")
        }
        .menuBarExtraStyle(.window)
    }
}

final class MenuModel: ObservableObject {
    @Published var draft: Profile?
    @Published var showOthers = false
}

final class FormModel: ObservableObject {
    @Published var profile: Profile
    @Published var dnsText: String

    init(_ profile: Profile) {
        self.profile = profile
        dnsText = profile.dns.joined(separator: ", ")
    }

    var dns: [String] {
        dnsText.split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
    }

    var isValid: Bool {
        !profile.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !profile.ssid.trimmingCharacters(in: .whitespaces).isEmpty
            && [profile.ip, profile.subnet, profile.gateway].allSatisfy(IPv4.isValid)
            && dns.allSatisfy(IPv4.isValid)
    }

    var result: Profile {
        var saved = profile
        saved.name = saved.name.trimmingCharacters(in: .whitespaces)
        saved.ssid = saved.ssid.trimmingCharacters(in: .whitespaces)
        saved.dns = dns
        return saved
    }
}

struct MenuView: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var model = MenuModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let draft = model.draft {
                ProfileForm(profile: draft) { model.draft = nil }
                    .id(draft.id)
            } else {
                header
                if !state.locationAuthorized { permissionNotice }
                if let error = state.lastError { notice(error, color: .red) }
                Divider()
                currentNetwork
                if !state.otherNetworks.isEmpty { otherNetworks }
                Divider()
                footer
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { state.scheduleRefresh(after: 0) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.ssid ?? "Nessuna rete Wi-Fi").font(.headline)
            if !state.live.ip.isEmpty {
                Text("\(state.live.manual ? "IP statico" : "DHCP") · \(state.live.ip)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Gateway \(state.live.gateway.isEmpty ? "—" : state.live.gateway) · DNS \(state.live.dns.isEmpty ? "automatici" : state.live.dns.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            notice("Per leggere il nome della rete serve il permesso di Localizzazione.", color: .orange)
            Button("Apri Impostazioni") { state.openLocationSettings() }
        }
    }

    private var currentNetwork: some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.ssid != nil {
                ChoiceRow(title: "DHCP automatico", subtitle: nil, selected: state.activeProfile == nil) { state.useDHCP() }
                ForEach(state.currentProfiles) { profile in
                    profileRow(profile)
                }
            }
            Button {
                model.draft = newProfile()
            } label: {
                Label("Nuovo profilo", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var otherNetworks: some View {
        DisclosureGroup("Altre reti", isExpanded: $model.showOthers) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(state.otherNetworks, id: \.ssid) { network in
                    Text(network.ssid).font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                    ForEach(network.profiles) { profile in
                        profileRow(profile)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Applica automaticamente", isOn: Binding(get: { state.data.autoApply }, set: state.setAutoApply))
            Toggle("Avvia al login", isOn: Binding(get: { state.launchAtLogin }, set: state.setLaunchAtLogin))
            HStack {
                Spacer()
                Button("Esci") { NSApplication.shared.terminate(nil) }
            }
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        HStack(spacing: 8) {
            ChoiceRow(title: profile.name, subtitle: profile.ip, selected: state.isActive(profile)) { state.activate(profile) }
            Button { model.draft = profile } label: { Image(systemName: "pencil") }
                .buttonStyle(.plain)
                .help("Modifica")
            Button { state.delete(profile) } label: { Image(systemName: "trash") }
                .buttonStyle(.plain)
                .help("Elimina")
        }
    }

    private func notice(_ text: String, color: Color) -> some View {
        Text(text).font(.caption).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }

    private func newProfile() -> Profile {
        let live = state.live
        return Profile(
            name: "",
            ssid: state.ssid ?? "",
            ip: live.ip,
            subnet: live.subnet.isEmpty ? "255.255.255.0" : live.subnet,
            gateway: live.gateway,
            dns: live.dns.isEmpty ? [live.gateway, "8.8.8.8"].filter { !$0.isEmpty } : live.dns
        )
    }
}

struct ChoiceRow: View {
    let title: String
    let subtitle: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(title)
                Spacer()
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }
}

struct ProfileForm: View {
    @EnvironmentObject private var state: AppState
    @StateObject private var model: FormModel
    private let isNew: Bool
    private let close: () -> Void

    init(profile: Profile, close: @escaping () -> Void) {
        _model = StateObject(wrappedValue: FormModel(profile))
        isNew = profile.name.isEmpty
        self.close = close
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isNew ? "Nuovo profilo" : "Modifica profilo").font(.headline)
            field("Nome", text: $model.profile.name, prompt: "es. FritzBox")
            field("Rete", text: $model.profile.ssid, prompt: "Nome della rete Wi-Fi")
            field("IP", text: $model.profile.ip, prompt: "192.168.1.123")
            field("Subnet", text: $model.profile.subnet, prompt: "255.255.255.0")
            field("Gateway", text: $model.profile.gateway, prompt: "192.168.1.1")
            field("DNS", text: $model.dnsText, prompt: "192.168.1.1, 8.8.8.8")
            HStack {
                Spacer()
                Button("Annulla", action: close).keyboardShortcut(.cancelAction)
                Button("Salva") {
                    state.save(model.result)
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.isValid)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        HStack {
            Text(label).frame(width: 62, alignment: .leading).foregroundStyle(.secondary)
            TextField(prompt, text: text).textFieldStyle(.roundedBorder)
        }
    }
}
