import SwiftUI

struct ContentView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(selection: $store.selection)

            Divider()

            Group {
                switch store.selection {
                case .devices: DeviceDashboardView(store: store)
                case .settings: SettingsView(store: store)
                case .help: HelpView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $store.showingQR, onDismiss: store.closeQR) {
            QRCastSheet(store: store)
        }
    }
}

private struct AppSidebar: View {
    @Binding var selection: NavigationSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if let image = ResourceLocator.image(named: "logo.png") {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    Image(systemName: "viewfinder")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 30, height: 30)
                }

                Text("Rokid 投屏助手")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 24)

            SidebarButton(section: .devices, selection: $selection)

            Spacer(minLength: 40)

            SidebarButton(section: .settings, selection: $selection)
            SidebarButton(section: .help, selection: $selection)
                .padding(.bottom, 18)
        }
        .frame(width: 216)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct SidebarButton: View {
    let section: NavigationSection
    @Binding var selection: NavigationSection

    var body: some View {
        Button {
            selection = section
        } label: {
            Label {
                Text(LocalizedStringKey(section.title))
            } icon: {
                Image(systemName: section.systemImage)
            }
                .font(.system(size: 14, weight: selection == section ? .semibold : .regular))
                .foregroundStyle(selection == section ? Color.blue : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selection == section ? Color.blue.opacity(0.09) : .clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }
}
