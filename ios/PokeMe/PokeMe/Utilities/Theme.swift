import SwiftUI

/// Centralized design tokens for consistent styling across PokeMe.
enum Theme {

    // MARK: - Spacing (8-point grid)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let base: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radii
    enum Radius {
        static let input: CGFloat = 12
        static let card: CGFloat = 16
        static let pill: CGFloat = 20
        static let chip: CGFloat = 10
    }

    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing
    )
    static let heroGradient = LinearGradient(
        colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let successGradient = LinearGradient(
        colors: [.green, .mint], startPoint: .leading, endPoint: .trailing
    )
    static let groupGradient = LinearGradient(
        colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // MARK: - Surface Colors
    enum Surface {
        static let primary = Color(uiColor: .systemBackground)
        static let secondary = Color(uiColor: .secondarySystemBackground)
        static let grouped = Color(uiColor: .systemGray6)
    }

    // MARK: - Animation Presets
    enum Anim {
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let quick = Animation.easeInOut(duration: 0.2)
        static let standard = Animation.easeInOut(duration: 0.3)
    }
}

// MARK: - View Helpers

extension View {
    /// Primary CTA gradient button style (orange → pink).
    func primaryCTAStyle() -> some View {
        self
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.primaryGradient)
            .cornerRadius(Theme.Radius.pill)
            .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    /// Standard card background with shadow.
    func cardStyle(radius: CGFloat = Theme.Radius.card) -> some View {
        self
            .background(Theme.Surface.primary)
            .cornerRadius(radius)
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }

    /// Tinted section chip (for sport or skill labels).
    func chipStyle(color: Color = .orange, filled: Bool = false) -> some View {
        self
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm / 2)
            .background(filled ? color : color.opacity(0.12))
            .foregroundColor(filled ? .white : color)
            .cornerRadius(Theme.Radius.chip)
    }
}
