import SwiftUI

struct GradientText: View {
    let text: String
    var font: Font = .title
    var colors: [Color] = [.primary, .primary.opacity(0.7)]

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}
