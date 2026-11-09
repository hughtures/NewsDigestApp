import SwiftUI

struct GlassButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    BlurredBackground(material: .hudWindow)
                    Color.white.opacity(isHovered ? 0.15 : 0.08)
                }
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.02 : 1.0))
            .brightness(isHovered ? 0.05 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}
