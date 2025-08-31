import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.orange.opacity(0.8),
                    Color.red.opacity(0.6),
                    Color.orange.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App Icon Placeholder
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.8), value: showContent)
                }
                
                // App Name
                Text("Cheffy-AI")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.easeIn(duration: 0.8).delay(0.2), value: showContent)
                
                // Tagline
                Text("Your AI Chef Companion")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.easeIn(duration: 0.8).delay(0.4), value: showContent)
                
                // Loading indicator
                if showContent {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .animation(.easeIn(duration: 0.8).delay(0.6), value: showContent)
                }
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeIn(duration: 0.8)) {
                showContent = true
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
