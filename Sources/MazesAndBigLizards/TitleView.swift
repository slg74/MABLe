import SwiftUI

struct TitleView: View {
    @EnvironmentObject var gs: GameState
    @State private var dragonScale: CGFloat = 0.8
    @State private var dragonOpacity: Double = 0.6
    @State private var glowRadius: CGFloat = 5
    @State private var torchFlicker: Bool = false
    @State private var titleOffset: CGFloat = -40
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background: dark stone
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.02, blue: 0.05),
                         Color(red: 0.08, green: 0.04, blue: 0.08),
                         Color(red: 0.03, green: 0.02, blue: 0.05)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Stone texture blocks
            Canvas { ctx, size in
                for row in 0..<20 {
                    for col in 0..<7 {
                        let offset: CGFloat = (row % 2 == 0) ? 0 : 30
                        let rect = CGRect(x: CGFloat(col) * 58 + offset - 10, y: CGFloat(row) * 44,
                                         width: 52, height: 38)
                        ctx.stroke(Path(rect), with: .color(Color(white: 0.12)), lineWidth: 1)
                    }
                }
            }.opacity(0.4)

            VStack(spacing: 0) {
                // Torches
                HStack {
                    TorchView(flicker: torchFlicker)
                    Spacer()
                    TorchView(flicker: !torchFlicker)
                }
                .padding(.horizontal, 40)
                .padding(.top, 60)

                Spacer().frame(height: 16)

                // Dragon silhouette
                Text("🐉")
                    .font(.system(size: 90))
                    .scaleEffect(dragonScale)
                    .opacity(dragonOpacity)
                    .shadow(color: .red.opacity(0.8), radius: glowRadius)

                Spacer().frame(height: 16)

                // Title
                VStack(spacing: 4) {
                    Text("MAZES &")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(red: 1, green: 0.8, blue: 0.1),
                                                    Color(red: 1, green: 0.4, blue: 0.0)],
                                           startPoint: .top, endPoint: .bottom))
                        .shadow(color: .orange.opacity(0.8), radius: 8)

                    Text("BIG LIZARDS")
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(red: 1, green: 0.3, blue: 0.1),
                                                    Color(red: 0.6, green: 0.1, blue: 0.0)],
                                           startPoint: .top, endPoint: .bottom))
                        .shadow(color: .red.opacity(0.9), radius: 10)
                }
                .offset(y: titleOffset)
                .opacity(titleOpacity)

                Text("A THAC0-BASED ADVENTURE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
                    .tracking(4)
                    .padding(.top, 4)
                    .opacity(titleOpacity)

                Spacer().frame(height: 40)

                // Decorative divider
                HStack(spacing: 8) {
                    Rectangle().frame(height: 1).foregroundColor(Color(white: 0.25))
                    Text("⚔️  🐲  ⚔️")
                        .font(.system(size: 14))
                    Rectangle().frame(height: 1).foregroundColor(Color(white: 0.25))
                }
                .padding(.horizontal, 30)
                .opacity(titleOpacity)

                Spacer().frame(height: 32)

                // Flavor text
                Text("\"Gather 'round the table.\"\n— Daemon, your DM")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
                    .italic()
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)

                Spacer().frame(height: 48)

                // Buttons
                VStack(spacing: 14) {
                    Button("⚔️  ROLL A CHARACTER") {
                        gs.screen = .characterCreation
                    }
                    .buttonStyle(MetalButtonStyle(color: Color(red: 0.7, green: 0.1, blue: 0.1)))

                    Text("THAC0 • 1d4–1d20 • Dungeon Crawling\nGoblins • Trolls • Big Lizards")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                        .multilineTextAlignment(.center)
                }
                .opacity(titleOpacity)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                dragonScale = 1.0
                dragonOpacity = 1.0
                glowRadius = 18
            }
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                torchFlicker.toggle()
            }
        }
    }
}

struct TorchView: View {
    var flicker: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(flicker ? "🔥" : "🕯️")
                .font(.system(size: 24))
                .shadow(color: .orange.opacity(0.8), radius: flicker ? 12 : 6)
            Rectangle()
                .frame(width: 4, height: 24)
                .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.1))
        }
    }
}
