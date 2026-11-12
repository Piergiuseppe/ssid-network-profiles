# ssid-network-profiles

A macOS menu bar app that applies a static IP, router and DNS servers based on the Wi-Fi network you are connected to. Keep several profiles per network, switch between them with one click, and fall back to DHCP everywhere else. Profiles can be exported to a file and imported on another Mac.

**[Download the latest release](https://github.com/Piergiuseppe/ssid-network-profiles/releases/latest)**

Requires macOS 14 or later, on Apple Silicon or Intel. Available in English, Italian, Spanish, French and German.

## Install

Open the `.dmg` and drag the app to `Applications`. The app is not signed with an Apple Developer ID, so unblock it once before the first launch:

```bash
xattr -dr com.apple.quarantine "/Applications/WiFi Profili.app"
```

On first launch macOS asks for the Location permission, which it requires from any app that reads the Wi-Fi network name. Your location is never read or sent anywhere.

## Verify the download

Releases are built by GitHub Actions from the matching tag, never uploaded by hand. To check your download, print its SHA-256 hash and compare it with the one GitHub shows next to the file on the release page:

```bash
shasum -a 256 WiFi-Profili-<version>.dmg
```

## Build

```bash
./build.sh install
```

## License

[MIT](LICENSE)
