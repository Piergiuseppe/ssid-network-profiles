# ssid-network-profiles

A macOS menu bar app that applies a static IP, gateway and DNS servers based on the Wi-Fi network you are connected to. Keep several profiles per network, switch between them with one click, and fall back to DHCP everywhere else.

**[Download the latest release](https://github.com/Piergiuseppe/ssid-network-profiles/releases/latest)**

Requires macOS 14 or later, on Apple Silicon or Intel. The interface is in Italian.

## Install

Unzip the download, move the app to `Applications`, then unblock it, since it is not signed with an Apple Developer ID:

```bash
xattr -dr com.apple.quarantine "/Applications/WiFi Profili.app"
```

On first launch macOS asks for the Location permission, which it requires from any app that reads the Wi-Fi network name. Your location is never read or sent anywhere.

## Verify the download

Releases are built by GitHub Actions from the matching tag, never uploaded by hand.

```bash
shasum -a 256 -c WiFi-Profili-<version>.zip.sha256
gh attestation verify WiFi-Profili-<version>.zip --repo Piergiuseppe/ssid-network-profiles
```

## Build

```bash
./build.sh install
```

## License

[MIT](LICENSE)
