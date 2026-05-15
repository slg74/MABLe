import SwiftUI

// MARK: - Music toggle (shared across all screens)

struct MusicToggleButton: View {
    @State private var muted = false
    @State private var vol: Float = AmbientAudio.shared.volume

    var body: some View {
        Menu {
            // Mute toggle
            Button {
                muted.toggle()
                AmbientAudio.shared.isMuted = muted
            } label: {
                Label(muted ? "Unmute Music" : "Mute Music",
                      systemImage: muted ? "speaker.slash" : "speaker.wave.2")
            }
            // Volume presets
            Divider()
            ForEach([("Low", Float(0.15)), ("Medium", Float(0.35)), ("High", Float(0.65))],
                    id: \.0) { label, v in
                Button("\(label) Volume") {
                    vol = v
                    AmbientAudio.shared.volume = v
                    if muted { muted = false; AmbientAudio.shared.isMuted = false }
                }
            }
        } label: {
            Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 14))
                .foregroundColor(muted ? Color(white: 0.3) : Color(white: 0.6))
                .frame(width: 32, height: 32)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var gs: GameState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch gs.screen {
                case .title:             TitleView()
                case .characterCreation: CharacterCreationView()
                case .tableScene:        TableSceneView()
                case .overworld:         OverworldView()
                case .dungeon:           DungeonView()
                case .encounter:         EncounterRevealView()
                case .combat:            CombatView()
                case .monsterDefeated:   MonsterDefeatedView()
                case .levelUp:           LevelUpView()
                case .victory:           VictoryView()
                case .gameOver:          GameOverView()
                case .characterSheet:    CharacterSheetView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.4), value: gs.screen)

            // Floating notification banner
            if gs.showNotification {
                VStack {
                    Text(gs.notification)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.yellow)
                        .cornerRadius(8)
                        .shadow(radius: 8)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: gs.showNotification)
                .zIndex(100)
            }
        }
        .frame(width: 390, height: 844)
    }
}

// MARK: - Level Up

struct LevelUpView: View {
    @EnvironmentObject var gs: GameState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("⬆️ LEVEL UP! ⬆️")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))

                if let p = gs.player {
                    Text("\(p.name) is now Level \(p.level)!")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Max HP: \(p.maxHP)")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.green)
                    Text("THAC0: \(p.thac0)")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                Text("The DM nods approvingly.\n\"Gnarly. Real gnarly.\"")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button("Continue ▶") {
                    if gs.combatReturnScreen == .overworld {
                        gs.screen = .overworld
                        AmbientAudio.shared.play(.overworld)
                    } else {
                        gs.checkDungeonCleared()
                    }
                }
                .buttonStyle(MetalButtonStyle(color: .purple))
            }
            .padding(32)
        }
    }
}

// MARK: - Victory

struct VictoryView: View {
    @EnvironmentObject var gs: GameState
    @State private var scale: CGFloat = 0.5

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.4, green: 0.0, blue: 0.0)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🏆").font(.system(size: 80)).scaleEffect(scale)
                    .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { scale = 1.0 } }

                Text("THE BIG LIZARD IS SLAIN")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .multilineTextAlignment(.center)

                if let p = gs.player {
                    VStack(spacing: 8) {
                        Text("\(p.name) — Level \(p.level) \(p.characterClass.rawValue)")
                        Text("XP Earned: \(p.experience)")
                        Text("Dungeon Levels: \(gs.dungeonLevel)")
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.yellow)
                }

                Text("The DM slams his fist on the table.\n\"DUDE. That was BRUTAL. Sabbath would be proud.\"")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()

                Button("Play Again") { gs.reset() }
                    .buttonStyle(MetalButtonStyle(color: .red))
            }
            .padding(32)
        }
    }
}

// MARK: - Game Over

struct GameOverView: View {
    @EnvironmentObject var gs: GameState
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("💀").font(.system(size: 80))
                Text("YOU HAVE DIED")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                if let p = gs.player {
                    Text("\(p.name)\nfell in the dungeon.")
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                Text("\"I saw that coming,\" says the DM.\n\"...from session one.\"")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .multilineTextAlignment(.center)
                Button("Roll a New Character") { gs.reset() }
                    .buttonStyle(MetalButtonStyle(color: .red))
            }
            .padding(32)
            .opacity(opacity)
            .onAppear { withAnimation(.easeIn(duration: 1.0)) { opacity = 1.0 } }
        }
    }
}

// MARK: - Shared Button Style

struct MetalButtonStyle: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced).bold())
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? color.opacity(0.6) : color.opacity(0.85))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 1.5))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}
