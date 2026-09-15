import SwiftUI

/// The mark, small, wherever a widget wants to say whose it is.
///
/// A template image so it takes the tint it is given rather than carrying its
/// own colour into somebody else's palette.
struct LaylaBadge: View {
    var size: CGFloat = 18
    var tint: Color = Layl.gold

    var body: some View {
        Image("LaylaMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .foregroundStyle(tint)
            .accessibilityLabel("Layla Pro")
    }
}
