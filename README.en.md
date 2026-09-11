# Rokid Wireless Projection Assistant

[中文](README.md)

Rokid Wireless Projection Assistant is a desktop tool for Rokid eyewear. It supports wireless casting for **Rokid Glasses, Rokid AR Lite, and Rokid AR Studio**, together with an ADB Shell and common ADB operations.

## Features

- QR-code connection and wireless casting for Rokid Glasses
- IP-based wireless casting for Rokid AR Lite and Rokid AR Studio
- Wireless ADB discovery, connection, and status management
- ADB Shell and common ADB operations
- Low-latency screen casting powered by scrcpy
- Current Mac Wi-Fi SSID detection for QR-code generation
- Chinese and English user interfaces
- Support for macOS

## Software Installation and Usage

This section is for users who want to install and use the released software. Downloading or compiling the source code is not required.

### Download the Software

Download the packages from the [v2.0.4 release](https://github.com/JellyFlow/Rokid-Wireless-ADB-Source-Code/releases/tag/Latest):

- macOS: `Rokid-Wireless-Projection-2.0.4.dmg`, universal for Apple Silicon (`arm64`) and Intel (`x86_64`)
- Windows x64: `Rokid-Wireless-Projection-2.0.1-win-x64-setup.exe`
- Glasses-side QR scanner APK: `RokidMirrorScan-v5-1.0.4-20260803-204722-system-signed.apk`

### Software Requirements

- macOS 13.0 or later, or a compatible Windows x64 environment
- Network connectivity between the computer and the glasses
- Local Network and Location Services permissions for QR-code connection; macOS requires location permission to expose the current Wi-Fi SSID

### macOS Installation

1. Open the DMG and drag **Rokid 无线投屏助手.app** into **Applications**.
2. If macOS blocks the first launch, open **System Settings > Privacy & Security** and click **Open Anyway** in the Security section.
3. Open **System Settings > Privacy & Security > Local Network** and allow Rokid Wireless Projection Assistant.
4. Quit the application completely and reopen it.

### Windows Installation

1. Run `Rokid-Wireless-Projection-2.0.1-win-x64-setup.exe`.
2. Follow the installer prompts to complete installation and launch the application.
3. If Windows Defender or SmartScreen displays a warning, verify the package source and allow the installer to run.

### Using the Software

- **Rokid Glasses, glasses side:** In Rokid AI / Hi Rokid, open **Toolbox > Glasses App Management > Install New App**, then install the glasses-side QR scanner APK from the release.
- **Rokid Glasses, computer side:** Click **QR Code Casting** in Rokid Wireless Projection Assistant, enter the Wi-Fi information, and scan the generated QR code with the glasses.
- **Rokid AR Lite / Rokid AR Studio:** Make sure the computer and glasses are on the same network, enter the device IP address, and click **Start Wireless Casting**.
- Use ADB features only with devices you own or are authorized to manage.

#### macOS Permissions

If the application cannot read the SSID or receive a callback from the glasses:

1. Open **System Settings > Privacy & Security > Local Network** and allow Rokid Wireless Projection Assistant.
2. Open **System Settings > Privacy & Security > Location Services** and allow the application.
3. Quit the application completely and reopen it.

## Source Development and Building

This section is for developers who want to inspect, modify, build, or package the source code. Regular software users do not need to run these commands.

### Development Requirements

- macOS 13.0 or later
- Xcode Command Line Tools
- Swift 5.10 or a compatible version
- Python 3, only when packaging the DMG

### Building from Source

Open Terminal and enter the source directory:

```bash
cd "$HOME/Desktop/Rokid-Wireless-ADB-Source-Code"
```

Build the SwiftPM executable:

```bash
swift build
```

Build and launch the universal `.app` bundle:

```bash
./script/build_and_run.sh run
```

Build and verify the `.app` without launching it:

```bash
./script/build_and_run.sh --build-only
```

Create the installer DMG:

```bash
./script/package_dmg.sh
```

Build outputs are written to `dist/`:

- `dist/Rokid 无线投屏助手.app`
- `dist/Rokid-Wireless-Projection-2.0.4.dmg`

On its first run, the DMG packaging script creates a Python virtual environment under `.codex/dmgbuild-venv/` and installs `dmgbuild==1.6.5`.

### Project Structure

```text
Rokid-Wireless-ADB-Source-Code/
├── Package.swift                    # SwiftPM package and macOS deployment target
├── README.md                        # Chinese documentation
├── README.en.md                     # English documentation
├── Sources/
│   └── RokidNative/
│       ├── App/
│       │   └── RokidNativeApp.swift # Application entry point and window setup
│       ├── Models/
│       │   └── AppModels.swift      # Device, casting, and application models
│       ├── Services/
│       │   ├── ADBService.swift     # ADB connection, commands, and casting control
│       │   ├── CallbackServer.swift # Wireless ADB HTTP callback server
│       │   ├── CommandRunner.swift  # Local process and command execution
│       │   ├── LocalNetworkPermissionService.swift
│       │   ├── LocationPermissionService.swift
│       │   ├── QRCodeService.swift  # Protocol JSON and QR-code generation
│       │   └── SystemWifiService.swift # Current Wi-Fi/SSID detection
│       ├── Stores/
│       │   └── AppStore.swift       # Global state and workflow coordination
│       ├── Support/
│       │   ├── Localization.swift   # Localization support
│       │   └── ResourceLocator.swift # Bundled resource lookup
│       └── Views/
│           ├── Components.swift     # Shared SwiftUI components
│           ├── ContentView.swift    # Main view
│           ├── DeviceDashboardView.swift
│           ├── HelpView.swift
│           ├── QRCastSheet.swift    # QR-code casting sheet
│           └── SettingsView.swift
├── Resources/
│   ├── Info.plist                   # Bundle metadata and permission descriptions
│   ├── RokidNative.entitlements     # Code-signing entitlements
│   ├── icon.icns                    # macOS application icon
│   ├── 安装说明.txt                  # Installation guide included in the DMG
│   ├── en.lproj/                    # English localization resources
│   ├── assets/                      # Logos, product images, and SVG assets
│   └── bin/
│       ├── adb                      # Universal arm64 + x86_64 ADB binary
│       ├── scrcpy                   # Universal arm64 + x86_64 scrcpy binary
│       ├── scrcpy-server            # Android-side scrcpy server
│       ├── rokid-adb-proxy.js       # ADB compatibility proxy
│       └── LICENSE.scrcpy           # scrcpy license
├── Tests/
│   └── RokidNativeTests/            # Callback, QR protocol, and product test sources
└── script/
    ├── build_and_run.sh             # Universal app build, signing, and launch
    ├── package_dmg.sh               # DMG creation and validation
    ├── prepare_universal_scrcpy.sh  # Prepares the universal scrcpy binary
    ├── create_dmg_background.swift  # Generates the DMG background image
    └── dmg_settings.py              # DMG window layout
```

The following directories are generated and are not source files:

- `.build/`: SwiftPM build cache
- `dist/`: generated application and DMG
- `.codex/signing/`: temporary local code-signing keychain
- `.codex/dmgbuild-venv/`: Python environment used for DMG packaging

### Debugging Commands

```bash
# Launch with LLDB
./script/build_and_run.sh --debug

# Stream process logs
./script/build_and_run.sh --logs

# Stream application telemetry
./script/build_and_run.sh --telemetry

# Launch and verify the process and signature
./script/build_and_run.sh --verify
```

## Security

Use ADB Shell and other ADB operations only with devices you own or are explicitly authorized to manage. A generated QR code may contain Wi-Fi credentials; do not share QR-code screenshots or protocol JSON with unauthorized people.

## Third-Party Components

This project bundles ADB and scrcpy. The scrcpy license is available at `Resources/bin/LICENSE.scrcpy`. Review and comply with all applicable third-party licenses before publishing or redistributing the application.
