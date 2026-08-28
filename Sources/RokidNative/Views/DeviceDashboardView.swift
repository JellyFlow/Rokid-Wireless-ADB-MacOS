import SwiftUI

struct DeviceDashboardView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ConnectionHeading(
                    device: store.selectedDevice,
                    selectedProduct: store.selectedProduct,
                    batteryLevel: store.deviceDetails.batteryLevel
                )
                ProductSelector(store: store)

                HStack(alignment: .top, spacing: 18) {
                    DeviceStatusCard(store: store)
                    MacWifiStatusCard(store: store)
                }

                if store.selectedProduct == .glasses {
                    WifiManagementCard(store: store)

                    HStack(alignment: .top, spacing: 18) {
                        WiredProjectionCard(store: store)
                        WirelessProjectionCard(store: store)
                    }
                } else {
                    ARWirelessProjectionCard(store: store)
                }

                StatusBanner(state: store.operationState)
            }
            .padding(.horizontal, 34)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: 1220)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ConnectionHeading: View {
    let device: ADBDevice?
    let selectedProduct: RokidProduct
    let batteryLevel: Int?

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: 4, height: 24)

            Text(device?.displayName ?? selectedProduct.rawValue)
                .font(.system(size: 17, weight: .semibold))

            Spacer()

            if let batteryLevel {
                HStack(spacing: 4) {
                    Image(systemName: batterySymbol(for: batteryLevel))
                        .foregroundStyle(batteryLevel > 20 ? Color.green : Color.red)
                    Text("\(batteryLevel)%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 28)
    }

    private func batterySymbol(for level: Int) -> String {
        switch level {
        case 76...: return "battery.100"
        case 51...: return "battery.75"
        case 26...: return "battery.50"
        case 1...: return "battery.25"
        default: return "battery.0"
        }
    }
}

private struct ProductSelector: View {
    @ObservedObject var store: AppStore

    var body: some View {
        HStack(spacing: 18) {
            ForEach(RokidProduct.allCases) { product in
                let isSelected = store.selectedProduct == product
                Button {
                    store.selectedProduct = product
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            if let image = ResourceLocator.image(named: product.assetName) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "eyeglasses")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(42)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 177)
                        .padding(.horizontal, 12)

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(LocalizedStringKey(product.subtitle))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 244)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isSelected ? Color.blue : Color(nsColor: .separatorColor).opacity(0.55),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.13) : .black.opacity(0.045),
                        radius: isSelected ? 6 : 3,
                        y: isSelected ? 2 : 1
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct DeviceStatusCard: View {
    @ObservedObject var store: AppStore

    private var connectedDevice: ADBDevice? {
        guard store.selectedDevice?.state == "device" else { return nil }
        return store.selectedDevice
    }

    var body: some View {
        NativeCard(inset: 18) {
            VStack(spacing: 10) {
                SectionTitle(
                    title: "设备信息",
                    systemImage: "info.circle",
                    status: connectedDevice == nil ? "未连接" : "已连接",
                    statusColor: connectedDevice == nil ? .secondary : .green
                )
                Divider()
                InfoRow(label: "设备 SN", value: connectedDevice == nil ? "--" : store.deviceDetails.hardwareSerial)
                InfoRow(label: "系统版本", value: store.deviceDetails.systemVersion)
                InfoRow(
                    label: "ADB 状态",
                    value: adbMode,
                    valueColor: connectedDevice == nil ? .primary : .green
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 164, alignment: .top)
    }

    private var adbMode: String {
        guard let connectedDevice else { return "--" }
        return connectedDevice.isUSB ? "有线模式" : "无线模式"
    }
}

private struct MacWifiStatusCard: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NativeCard(inset: 18) {
            VStack(spacing: 10) {
                SectionTitle(
                    title: "当前 Wi-Fi",
                    systemImage: "wifi",
                    status: store.macWifi.connected ? "已连接" : "未连接",
                    statusColor: store.macWifi.connected ? .green : .secondary,
                    iconColor: .blue
                )
                Divider()
                InfoRow(label: "SSID", value: store.macWifi.ssid.isEmpty ? "--" : store.macWifi.ssid)
                InfoRow(label: "本机 IP", value: store.macWifi.localIP.isEmpty ? "--" : store.macWifi.localIP)
                InfoRow(label: "设备 IP", value: store.deviceDetails.ipAddress)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 164, alignment: .top)
    }
}

private struct WifiManagementCard: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionTitle(
                title: "眼镜 Wi-Fi 管理",
                systemImage: "antenna.radiowaves.left.and.right",
                status: wifiStatusText,
                statusColor: wifiStatusColor,
                statusIndicatorColor: wifiStatusIndicatorColor
            )

            Divider()

            HStack(spacing: 16) {
                LabeledInput(title: "Wi-Fi 名称（SSID）") {
                    TextField("Wi-Fi 名称", text: $store.wifiSSID)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledInput(title: "密码") {
                    SecureField("输入 Wi-Fi 密码", text: $store.wifiPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 12) {
                Button("扫码连接投屏") { store.openQR() }
                    .buttonStyle(PrimaryButtonStyle())

                Button(LocalizedStringKey(store.deviceDetails.wifiEnabled ? "关闭眼镜 Wi-Fi" : "开启眼镜 Wi-Fi")) {
                    store.setDeviceWifi(enabled: !store.deviceDetails.wifiEnabled)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("连接 Wi-Fi") { store.connectDeviceWifi() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.usbDevice == nil)
            }
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.045), radius: 3, y: 1)
    }

    private var wifiStatusText: String {
        if store.deviceDetails.wifiConnected { return "Wi-Fi 已连接" }
        if store.deviceDetails.wifiEnabled { return "Wi-Fi 已开启，未连接" }
        return "Wi-Fi 未开启"
    }

    private var wifiStatusColor: Color {
        if store.deviceDetails.wifiConnected { return .green }
        if store.deviceDetails.wifiEnabled { return .orange }
        return .secondary
    }

    private var wifiStatusIndicatorColor: Color {
        store.deviceDetails.wifiEnabled && !store.deviceDetails.wifiConnected ? .yellow : wifiStatusColor
    }
}

private struct LabeledInput<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WiredProjectionCard: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NativeCard(inset: 18) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    title: "有线 ADB 投屏",
                    systemImage: "cable.connector",
                    status: store.usbDevice == nil ? "未连接" : "已连接",
                    statusColor: store.usbDevice == nil ? .secondary : .green
                )

                HStack(spacing: 12) {
                    Button("开启有线投屏") { store.startWiredMirror() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("断开有线 ADB") { store.stopWiredMirror() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(store.usbDevice == nil)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WirelessProjectionCard: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NativeCard(inset: 18) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    title: "无线 ADB 投屏",
                    systemImage: "wifi",
                    status: store.wirelessDevice == nil ? "未连接" : "已连接",
                    statusColor: store.wirelessDevice == nil ? .secondary : .green,
                    iconColor: .blue
                )

                HStack(spacing: 12) {
                    Button("开启无线投屏") { store.connectWireless() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("断开无线 ADB") { store.disconnectWireless() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(store.wirelessDevice == nil)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ARWirelessProjectionCard: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NativeCard(inset: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    title: "无线 ADB 投屏",
                    systemImage: "wifi",
                    status: store.wirelessDevice == nil ? "未连接" : "已连接",
                    statusColor: store.wirelessDevice == nil ? .secondary : .green,
                    iconColor: .blue
                )

                Divider()

                LabeledInput(title: "设备 IP") {
                    HStack(spacing: 8) {
                        TextField("设备 IPv4 地址", text: $store.wirelessIP)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                        Text(":5555")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Button("开启无线投屏") { store.connectWireless() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("断开无线 ADB") { store.disconnectWireless() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(store.wirelessDevice == nil)
                }
            }
        }
    }
}
