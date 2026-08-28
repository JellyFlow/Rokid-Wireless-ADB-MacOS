import SwiftUI

struct NativeCard<Content: View>: View {
    let inset: CGFloat
    let highlighted: Bool
    let content: Content

    init(inset: CGFloat = 20, highlighted: Bool = false, @ViewBuilder content: () -> Content) {
        self.inset = inset
        self.highlighted = highlighted
        self.content = content()
    }

    var body: some View {
        content
            .padding(inset)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        highlighted ? Color.blue : Color(nsColor: .separatorColor).opacity(0.55),
                        lineWidth: highlighted ? 1.25 : 1
                    )
            }
            .shadow(color: highlighted ? Color.blue.opacity(0.08) : .black.opacity(0.045), radius: highlighted ? 6 : 3, y: 2)
    }
}

struct SectionTitle: View {
    let title: String
    let systemImage: String
    var status: String?
    var statusColor: Color = .secondary
    var statusIndicatorColor: Color?
    var iconColor: Color = .primary

    var body: some View {
        HStack {
            Label {
                Text(LocalizedStringKey(title))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(iconColor)
                    .frame(width: 16)
            }
            .font(.headline)
            Spacer()
            if let status {
                HStack(spacing: 5) {
                    Circle().fill(statusIndicatorColor ?? statusColor).frame(width: 6, height: 6)
                    Text(LocalizedStringKey(status))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(statusColor.opacity(0.09))
                .clipShape(Capsule())
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(LocalizedStringKey(label)).foregroundStyle(.secondary)
            Spacer()
            Text(LocalizedStringKey(value))
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(.white)
            .background(buttonColor(configuration: configuration))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func buttonColor(configuration: Configuration) -> Color {
        guard isEnabled else { return Color.blue.opacity(0.48) }
        return configuration.isPressed ? Color.blue.opacity(0.78) : Color.blue
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(isEnabled ? Color.blue : Color.secondary)
            .background(Color.blue.opacity(configuration.isPressed ? 0.14 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isEnabled ? 1 : 0.55)
    }
}

struct StatusBanner: View {
    let state: OperationState

    var body: some View {
        if state != .idle {
            HStack(spacing: 8) {
                switch state {
                case .working:
                    ProgressView().controlSize(.small)
                case .success:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .failure:
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                case .idle:
                    EmptyView()
                }
                Text(LocalizedStringKey(state.message))
                    .font(.callout)
                    .foregroundStyle(stateColor)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(stateColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var stateColor: Color {
        switch state {
        case .failure: return .red
        case .success: return .green
        default: return .secondary
        }
    }
}
