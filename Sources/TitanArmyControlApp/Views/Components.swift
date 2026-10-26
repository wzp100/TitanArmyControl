import SwiftUI

/// A quiet settings group, with consistent insets and native controls inside.
struct SettingsGroup<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.small) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, Layout.compact)
            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Layout.groupRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Layout.groupRadius)
                    .strokeBorder(Palette.separator, lineWidth: 0.5)
            }
            if let footer {
                Text(footer)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Layout.compact)
            }
        }
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 48)
    }
}

struct SettingIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 24)
            .accessibilityHidden(true)
    }
}

struct ToneControl: View {
    let title: String
    let symbol: String
    let maximum: Int
    @Binding var value: Double
    let disabled: Bool
    let available: Bool
    let onChange: (Double) -> Void
    let onCommit: () -> Void
    var isMuted = false
    var muteLabel = ""
    var onMute: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Layout.medium) {
            if let onMute {
                Button(action: onMute) {
                    SettingIcon(symbol: isMuted ? "speaker.slash" : symbol)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(muteLabel)
                .help(muteLabel)
                .disabled(disabled || !available)
            } else {
                SettingIcon(symbol: symbol)
            }
            Text(title)
                .lineLimit(1)
                .frame(width: Layout.toneLabelWidth, alignment: .leading)
            Slider(
                value: Binding(get: { value }, set: onChange),
                in: 0...Double(max(maximum, 1)),
                onEditingChanged: { editing in
                    if !editing { onCommit() }
                }
            )
            .disabled(disabled || !available)
            .accessibilityLabel(title)
            .accessibilityValue(available ? "\(Int(value.rounded())) / \(maximum)" : "—")
            Text(available ? "\(Int(value.rounded()))" : "—")
                .monospacedDigit()
                .foregroundStyle(disabled || !available ? .secondary : .primary)
                .frame(width: 36, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(Layout.regular)
    }
}

struct StatusLabel: View {
    let title: String
    var symbol = "checkmark.circle.fill"
    var color: Color = .green

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }
}

struct NoticeBar: View {
    let notice: MonitorViewModel.Notice
    let dismissTitle: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Layout.medium) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(notice.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(dismissTitle)
            .accessibilityLabel(dismissTitle)
        }
        .padding(Layout.medium)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private var tint: Color {
        switch notice.level {
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    private var icon: String {
        switch notice.level {
        case .info: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }
}

/// A small display illustration, drawn with system colors instead of a bitmap.
struct DisplayIllustration: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .labelColor).opacity(colorScheme == .dark ? 0.7 : 0.85))
                ZStack {
                    Rectangle().fill(Color(nsColor: .windowBackgroundColor))
                    Circle()
                        .fill(Palette.accent.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .offset(x: 44, y: 30)
                    Circle()
                        .strokeBorder(Palette.accent.opacity(0.18), lineWidth: 16)
                        .frame(width: 112, height: 112)
                        .offset(x: -38, y: -20)
                }
                .frame(width: 162, height: 89)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(.top, 5)
            }
            .frame(width: 172, height: 104)
            Rectangle()
                .fill(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 12, height: 15)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 64, height: 4)
        }
        .frame(width: 188, height: 144)
        .accessibilityHidden(true)
    }
}
