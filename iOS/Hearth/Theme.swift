import SwiftUI
import UIKit

// MARK: - Palette: "reading nook"
// Warm honey-oak and deep forest green. Light mode is morning light through a
// frosted window; dark mode is an evening study lit by a lamp-glow amber.

extension Color {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Warm parchment page background.
    static let nookBackground = dynamic(
        light: UIColor(red: 0.96, green: 0.93, blue: 0.87, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.10, blue: 0.08, alpha: 1))

    /// Honey-oak. The signature accent.
    static let honey = dynamic(
        light: UIColor(red: 0.78, green: 0.55, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.91, green: 0.67, blue: 0.32, alpha: 1))

    /// Deep forest green. Structure, headers, primary buttons.
    static let forest = dynamic(
        light: UIColor(red: 0.12, green: 0.26, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.76, blue: 0.65, alpha: 1))

    /// Panel fill behind glass.
    static let paneFill = dynamic(
        light: UIColor(red: 1.0, green: 0.99, blue: 0.96, alpha: 0.65),
        dark: UIColor(red: 0.11, green: 0.15, blue: 0.12, alpha: 0.72))

    /// Soft ink for body text.
    static let ink = dynamic(
        light: UIColor(red: 0.16, green: 0.14, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.93, green: 0.90, blue: 0.83, alpha: 1))

    /// Muted ink for secondary text.
    static let inkSoft = dynamic(
        light: UIColor(red: 0.42, green: 0.39, blue: 0.33, alpha: 1),
        dark: UIColor(red: 0.66, green: 0.64, blue: 0.57, alpha: 1))

    /// Lamp glow used for streaks and highlights in dark mode.
    static let lampGlow = dynamic(
        light: UIColor(red: 0.86, green: 0.62, blue: 0.24, alpha: 1),
        dark: UIColor(red: 0.98, green: 0.76, blue: 0.38, alpha: 1))
}

// MARK: - Kid hues

enum KidPalette {
    /// Curated hues that sit well on the parchment and evening backgrounds.
    static let presets: [(name: String, hue: Double)] = [
        ("Clay", 18), ("Honey", 38), ("Moss", 105), ("Pine", 155),
        ("Lake", 200), ("Dusk", 250), ("Plum", 290), ("Berry", 335)
    ]

    static func color(hue: Double, in scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return Color(hue: hue / 360, saturation: 0.45, brightness: 0.82)
        }
        return Color(hue: hue / 360, saturation: 0.52, brightness: 0.62)
    }

    static func wash(hue: Double, in scheme: ColorScheme) -> Color {
        if scheme == .dark {
            return Color(hue: hue / 360, saturation: 0.35, brightness: 0.30)
        }
        return Color(hue: hue / 360, saturation: 0.18, brightness: 0.97)
    }
}

extension Kid {
    func tint(in scheme: ColorScheme) -> Color { KidPalette.color(hue: hue, in: scheme) }
    func wash(in scheme: ColorScheme) -> Color { KidPalette.wash(hue: hue, in: scheme) }
}

// MARK: - Frosted window pane (the glass panel)

struct WindowPane: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.paneFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func windowPane(cornerRadius: CGFloat = 20) -> some View {
        modifier(WindowPane(cornerRadius: cornerRadius))
    }
}

// MARK: - Nook background with soft morning light

struct NookBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.nookBackground.ignoresSafeArea()
            // Soft light falling across the page: a broad radial wash top-leading.
            RadialGradient(
                colors: scheme == .dark
                    ? [Color.lampGlow.opacity(0.14), Color.clear]
                    : [Color.white.opacity(0.75), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520)
            .ignoresSafeArea()
            RadialGradient(
                colors: scheme == .dark
                    ? [Color.forest.opacity(0.10), Color.clear]
                    : [Color.honey.opacity(0.10), Color.clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 600)
            .ignoresSafeArea()
        }
    }
}

// MARK: - Typography helpers

extension Font {
    /// Serif for headers: the reading-nook voice.
    static func nookTitle(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Rounded for numbers and chips.
    static func nookRounded(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Keyboard dismissal (applies to every text-input screen)

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded { _ in
                    UIApplication.shared.endEditing()
                }
            )
    }
}

extension View {
    /// Every screen with text input must apply this so a tap anywhere outside
    /// the field puts the keyboard away.
    func dismissesKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}

// MARK: - Shared small controls

struct PillButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nookRounded(14, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule().fill(prominent ? AnyShapeStyle(Color.forest) : AnyShapeStyle(.ultraThinMaterial))
            }
            .foregroundStyle(prominent ? Color.nookBackground : Color.forest)
            .overlay {
                Capsule().strokeBorder(Color.forest.opacity(prominent ? 0 : 0.25), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
