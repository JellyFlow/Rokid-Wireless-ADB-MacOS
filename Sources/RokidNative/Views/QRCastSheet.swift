import SwiftUI

struct QRCastSheet: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Rokid 扫码投屏")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    store.closeQR()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }

            if store.qrShowingConfiguration {
                configuration
            } else {
                preview
            }

            StatusBanner(state: store.qrState)
        }
        .padding(24)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var configuration: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Wi-Fi 名称（SSID）").font(.caption).foregroundStyle(.secondary)
                    TextField("Wi-Fi 名称", text: $store.wifiSSID)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("安全类型").font(.caption).foregroundStyle(.secondary)
                    Picker("安全类型", selection: $store.qrSecurity) {
                        Text("WPA").tag("WPA")
                        Text("WEP").tag("WEP")
                        Text("开放网络").tag("NOPASS")
                        Text("企业 Wi-Fi").tag("EAP")
                    }
                    .labelsHidden()
                }
                .frame(width: 145)
            }

            if store.qrSecurity != "NOPASS" {
                VStack(alignment: .leading, spacing: 5) {
                    Text("密码").font(.caption).foregroundStyle(.secondary)
                    SecureField("Wi-Fi 密码", text: $store.wifiPassword)
                }
            }

            if store.qrSecurity == "EAP" {
                VStack(alignment: .leading, spacing: 5) {
                    Text("企业身份").font(.caption).foregroundStyle(.secondary)
                    TextField("user@example.com", text: $store.qrIdentity)
                }
            }

            Button("生成投屏二维码") {
                store.generateQR()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var preview: some View {
        VStack(spacing: 12) {
            if let image = store.qrImage {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6).stroke(.quaternary)
                    }
                    .accessibilityLabel("Rokid 投屏二维码")
            }

            HStack(spacing: 10) {
                Button("重新生成", systemImage: "arrow.clockwise") { store.resetQR() }
                    .buttonStyle(.bordered)
                Button("完成", systemImage: "checkmark") { store.closeQR() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
