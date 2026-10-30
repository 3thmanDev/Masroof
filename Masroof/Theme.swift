import SwiftUI

enum Theme {
    static let background = Color(red: 0.945, green: 0.961, blue: 0.953)
    static let card = Color.white
    static let field = Color(red: 0.945, green: 0.961, blue: 0.953)
    static let ink = Color(red: 0.075, green: 0.125, blue: 0.106)
    static let secondary = Color(red: 0.353, green: 0.420, blue: 0.388)
    static let line = Color(red: 0.855, green: 0.890, blue: 0.875)

    static let accent = Color(red: 0.051, green: 0.416, blue: 0.322)
    static let accentSoft = Color(red: 0.875, green: 0.941, blue: 0.910)
    static let warn = Color(red: 0.659, green: 0.416, blue: 0.071)
    static let warnSoft = Color(red: 0.984, green: 0.941, blue: 0.855)
    static let bad = Color(red: 0.706, green: 0.196, blue: 0.122)
    static let badSoft = Color(red: 0.984, green: 0.898, blue: 0.878)

    /// The banknote-green panel that holds today's limit.
    static let hero = Color(red: 0.059, green: 0.231, blue: 0.188)
    static let heroInk = Color(red: 0.918, green: 0.961, blue: 0.941)
    static let heroMuted = Color(red: 0.655, green: 0.776, blue: 0.729)
    static let dotGood = Color(red: 0.435, green: 0.878, blue: 0.682)
    static let dotWarn = Color(red: 0.961, green: 0.769, blue: 0.420)
    static let dotBad = Color(red: 1.0, green: 0.549, blue: 0.467)
}

enum CairoWeight: String {
    case regular = "Cairo-Regular"
    case medium = "Cairo-Medium"
    case semibold = "Cairo-SemiBold"
    case bold = "Cairo-Bold"
    case extraBold = "Cairo-ExtraBold"
    case black = "Cairo-Black"
}

extension Font {
    static func cairo(_ size: CGFloat, _ weight: CairoWeight = .regular) -> Font {
        .custom(weight.rawValue, size: size)
    }
}

extension View {
    func card(cornerRadius: CGFloat = 22) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.card)
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 4)
        )
    }

    /// Arabic right-to-left layout, Cairo font and the light look, applied to the root and every sheet.
    func appEnvironment() -> some View {
        font(.cairo(17))
            .foregroundColor(Theme.ink)
            .tint(Theme.accent)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, DateText.locale)
            .preferredColorScheme(.light)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.cairo(17, .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
        }
        .buttonStyle(PressableStyle())
    }
}

struct Tag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.cairo(11, .medium))
            .foregroundColor(Theme.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .background(Capsule().fill(Theme.field))
            .fixedSize()
    }
}
