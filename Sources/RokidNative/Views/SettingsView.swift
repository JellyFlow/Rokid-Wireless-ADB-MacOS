import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("设置")
                    .font(.title2.weight(.semibold))

                NativeCard {
                    VStack(spacing: 0) {
                        settingRow(icon: "circle.lefthalf.filled", title: "外观") {
                            Picker("外观", selection: $store.preferredAppearance) {
                                Text("跟随系统").tag("system")
                                Text("浅色").tag("light")
                                Text("深色").tag("dark")
                            }
                            .labelsHidden()
                            .frame(width: 125)
                            .onChange(of: store.preferredAppearance) { _ in store.persistSettings() }
                        }
                        Divider()
                        settingRow(icon: "globe", title: "语言") {
                            Picker("语言", selection: $store.preferredLanguage) {
                                Text("跟随系统").tag(AppLanguage.system.rawValue)
                                Text("简体中文").tag(AppLanguage.simplifiedChinese.rawValue)
                                Text("English").tag(AppLanguage.english.rawValue)
                            }
                            .labelsHidden()
                            .frame(width: 125)
                            .onChange(of: store.preferredLanguage) { _ in store.persistSettings() }
                        }
                        Divider()
                        settingRow(icon: "info.circle", title: "关于") {
                            Text("Rokid 无线投屏助手 v2.0 原生版")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760)
        }
    }

    private func settingRow<Accessory: View>(
        icon: String,
        title: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(LocalizedStringKey(title))
            Spacer()
            accessory()
        }
        .padding(.vertical, 13)
    }
}
