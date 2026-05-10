import SwiftUI

struct ScanningLoadingView: View {
    @State private var move = false

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.11),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.11),
                            Color.white.opacity(0.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: geo.size.height / 3)
                .cornerRadius(geo.size.height / 12)
                .blur(radius: 6)
                .offset(y: move ? geo.size.height : -geo.size.height / 6)
                .animation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: move
                )
                .onAppear {
                    move = true
                }
        }
        .allowsHitTesting(false)
    }
}
