import SwiftUI

struct HelpView: View {
    private let steps = [
        "在设备页选择与眼镜对应的型号；连接成功后，应用会自动识别型号并更新状态。",
        "Rokid Glasses 有线投屏：使用 USB 开发线连接眼镜，然后点击“开启有线投屏”。",
        "Rokid Glasses 无线投屏：点击“扫码连接投屏”，填写 Wi-Fi 信息后使用眼镜扫描二维码。",
        "Rokid AR Lite / AR Studio：确认电脑和眼镜连接同一 Wi-Fi，填写设备 IP 后点击“开启无线投屏”。",
        "设备信息显示“已连接”且 ADB 状态为有线或无线模式后，投屏窗口会自动打开。"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("使用说明")
                    .font(.title2.weight(.semibold))

                NativeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 22, height: 22)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                                Text(LocalizedStringKey(step))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                        }
                    }
                }

            }
            .padding(28)
            .frame(maxWidth: 760)
        }
    }
}
