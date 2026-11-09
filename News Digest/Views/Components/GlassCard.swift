import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    BlurredBackground(material: .hudWindow)
                    Color.white.opacity(0.05)
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
    }
}
