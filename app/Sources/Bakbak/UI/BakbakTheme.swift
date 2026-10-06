import AppKit
import SwiftUI

/// Bakbak visual system locked to Refero **Steep** (steep.app).
/// Paper / mist / ink monochrome + rare blush peach callout. Parrot is imagery only.
enum BakbakTheme {
    // MARK: - Steep palette

    static let paper = Color(hex: 0xFFFFFF)
    static let mist = Color(hex: 0xF2F2F3)
    static let fog = Color(hex: 0xFAFAFB)
    static let ink = Color(hex: 0x17191C)
    static let slate = Color(hex: 0x777B86)
    static let ash = Color(hex: 0x979799)
    static let smoke = Color(hex: 0xA3A6AF)
    static let peach = Color(hex: 0xFBE1D1)
    static let sienna = Color(hex: 0x5D2A1A)
    static let hairline = Color(hex: 0xECECEC)

    static let radiusCard: CGFloat = 24
    static let radiusElevated: CGFloat = 20
    static let radiusInput: CGFloat = 16
    static let radiusImage: CGFloat = 12
    static let radiusPill: CGFloat = 9999

    // MARK: - Type helpers (Signifier → New York / Georgia; Sohne → SF)

    static func displayFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: - Parrot assets (imagery only — not a color accent)

    @MainActor
    static func parrotImage(preferLight: Bool = true) -> NSImage? {
        let names = preferLight
            ? ["bakbak-mac-light", "bakbak-mac-dark", "bakbak-parrot-black"]
            : ["bakbak-mac-dark", "bakbak-mac-light", "bakbak-parrot-black"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
            if let base = Bundle.main.resourceURL {
                let url = base.appendingPathComponent("\(name).png")
                if FileManager.default.fileExists(atPath: url.path),
                   let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }
        return nil
    }

    // MARK: - Formatters

    static func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 {
            let m = seconds / 60
            return m == 1 ? "1 min ago" : "\(m) min ago"
        }
        if seconds < 86_400 {
            let h = seconds / 3600
            return h == 1 ? "1 hr ago" : "\(h) hrs ago"
        }
        if seconds < 86_400 * 7 {
            let d = seconds / 86_400
            return d == 1 ? "Yesterday" : "\(d) days ago"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    static func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let m = s / 60
        let r = s % 60
        if m >= 60 {
            let h = m / 60
            return String(format: "%dh %02dm", h, m % 60)
        }
        return String(format: "%d:%02d", m, r)
    }

    static func audioSourceLabel(_ source: String) -> String {
        source == "microphone+system" ? "Mic + system" : "Microphone"
    }
}

// MARK: - Color hex

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - Shared components

struct BakbakFilledPill: View {
    let title: String
    var compact: Bool = false
    var expand: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BakbakTheme.bodyFont(compact ? 13 : 15, weight: .medium))
                .foregroundStyle(BakbakTheme.paper)
                .frame(maxWidth: expand ? .infinity : nil)
                .padding(.horizontal, compact ? 14 : 20)
                .padding(.vertical, compact ? 7 : 10)
                .background(BakbakTheme.ink, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct BakbakGhostPill: View {
    let title: String
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BakbakTheme.bodyFont(compact ? 13 : 15, weight: .regular))
                .foregroundStyle(BakbakTheme.ink)
                .padding(.horizontal, compact ? 14 : 20)
                .padding(.vertical, compact ? 7 : 10)
                .background(Color.clear, in: Capsule())
                .overlay(Capsule().stroke(BakbakTheme.ink, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Mist tag — typographic chip, not a colorful badge.
struct BakbakTag: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
            }
            Text(text)
                .font(BakbakTheme.bodyFont(12, weight: .regular))
        }
        .foregroundStyle(BakbakTheme.ash)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(BakbakTheme.mist, in: Capsule())
    }
}

struct BakbakEmptyHero: View {
    let title: String
    let subtitle: String
    var parrotSize: CGFloat = 96

    var body: some View {
        VStack(spacing: 20) {
            // Rare peach callout (one per empty surface)
            VStack(spacing: 16) {
                if let parrot = BakbakTheme.parrotImage() {
                    Image(nsImage: parrot)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: parrotSize, height: parrotSize)
                        .clipShape(RoundedRectangle(cornerRadius: BakbakTheme.radiusImage, style: .continuous))
                } else {
                    Image(systemName: "bird.fill")
                        .font(.system(size: parrotSize * 0.4))
                        .foregroundStyle(BakbakTheme.sienna)
                }
                Text(title)
                    .font(BakbakTheme.displayFont(28))
                    .tracking(-0.3)
                    .foregroundStyle(BakbakTheme.sienna)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(BakbakTheme.bodyFont(15))
                    .foregroundStyle(BakbakTheme.sienna.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 40)
            .frame(maxWidth: 420)
            .background(BakbakTheme.peach, in: RoundedRectangle(cornerRadius: BakbakTheme.radiusCard, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(BakbakTheme.paper)
    }
}

struct BakbakSegmentedControl<Tab: Hashable>: View {
    let tabs: [(Tab, String)]
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { tab, title in
                let selected = selection == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection = tab }
                } label: {
                    Text(title)
                        .font(BakbakTheme.bodyFont(14, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? BakbakTheme.paper : BakbakTheme.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(selected ? BakbakTheme.ink : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(BakbakTheme.mist)
        )
    }
}

/// Permission status as ink/ash dots — no green/red chromatics.
struct PermissionDot: View {
    let label: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ok ? BakbakTheme.ink : Color.clear)
                .overlay(Circle().stroke(ok ? BakbakTheme.ink : BakbakTheme.ash, lineWidth: 1.5))
                .frame(width: 7, height: 7)
            Text(label)
                .font(BakbakTheme.bodyFont(11))
                .foregroundStyle(ok ? BakbakTheme.slate : BakbakTheme.ash)
        }
    }
}

struct FloatingCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(BakbakTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: BakbakTheme.radiusElevated, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BakbakTheme.radiusElevated, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }
}

extension View {
    func bakbakFloatingCard() -> some View {
        modifier(FloatingCardModifier())
    }
}
