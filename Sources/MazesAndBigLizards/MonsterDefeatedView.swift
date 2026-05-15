import SwiftUI

struct MonsterDefeatedView: View {
    @EnvironmentObject var gs: GameState

    private let duration: Double = 5.0
    private let tickInterval: Double = 0.05
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    @State private var elapsed: Double = 0
    @State private var didNavigate = false

    var monster: Monster { gs.defeatedMonster ?? Monster.makeGoblin() }
    var partySize: Int { npcParty.count + 1 }
    var xpEach: Int { max(1, monster.xpValue / partySize) }
    var progress: Double { min(1.0, elapsed / duration) }
    var secondsLeft: Int { max(0, Int(ceil(duration - elapsed))) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.09, blue: 0.04),
                                    Color(red: 0.02, green: 0.05, blue: 0.02),
                                    Color(red: 0.03, green: 0.09, blue: 0.04)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                HStack {
                    Text("⚔️  ENEMY SLAIN")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                    Spacer()
                    Text(monster.icon)
                        .font(.system(size: 18))
                        .opacity(0.5)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.02, green: 0.12, blue: 0.04))

                ScrollView {
                    VStack(spacing: 16) {

                        // ── Defeated monster card ─────────────────────────
                        VStack(spacing: 8) {
                            ZStack {
                                Text(monster.icon)
                                    .font(.system(size: monster.isBoss ? 64 : 52))
                                    .opacity(0.35)
                                    .blur(radius: 1)
                                Text("💀")
                                    .font(.system(size: 24))
                                    .offset(x: 18, y: -18)
                            }

                            Text(monster.name)
                                .font(.system(size: monster.isBoss ? 18 : 15, weight: .black, design: .monospaced))
                                .foregroundColor(Color(white: 0.5))
                                .strikethrough(true, color: .red.opacity(0.6))

                            Text(monster.flavor)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(white: 0.3))
                                .italic()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 16)

                        // ── DM quote ──────────────────────────────────────
                        if !gs.dmQuote.isEmpty {
                            Text("🤘 \u{201C}\(gs.dmQuote)\u{201D}")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(white: 0.4))
                                .italic()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        // ── XP breakdown ──────────────────────────────────
                        VStack(spacing: 0) {
                            HStack {
                                Text("SPOILS OF BATTLE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(white: 0.35))
                                    .tracking(2)
                                Spacer()
                                Text("TOTAL: \(monster.xpValue) XP")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.07))

                            Rectangle().fill(Color(white: 0.14)).frame(height: 1)

                            // Player row
                            if let p = gs.player {
                                XPRow(icon: p.characterClass.icon,
                                      name: p.name,
                                      role: p.characterClass.rawValue,
                                      xp: xpEach,
                                      isPlayer: true)
                            }

                            // NPC rows
                            ForEach(npcParty, id: \.name) { member in
                                Rectangle().fill(Color(white: 0.10)).frame(height: 1)
                                XPRow(icon: member.icon,
                                      name: member.name,
                                      role: member.role,
                                      xp: xpEach,
                                      isPlayer: false)
                            }

                            Rectangle().fill(Color(white: 0.14)).frame(height: 1)

                            HStack {
                                Text("÷ \(partySize) members")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(white: 0.3))
                                Spacer()
                                Text("+\(xpEach) XP each")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.06))
                        }
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.25), lineWidth: 1))
                        .padding(.horizontal, 16)

                        // ── Countdown bar ─────────────────────────────────
                        VStack(spacing: 6) {
                            HStack {
                                Text("REST & REGROUP")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(white: 0.35))
                                    .tracking(2)
                                Spacer()
                                Text("\(secondsLeft)s")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(white: 0.4))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(white: 0.12))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.green.opacity(0.55))
                                        .frame(width: geo.size.width * (1.0 - progress))
                                        .animation(.linear(duration: tickInterval), value: progress)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            guard !didNavigate else { return }
            elapsed += tickInterval
            if elapsed >= duration {
                didNavigate = true
                navigate()
            }
        }
    }

    private func navigate() {
        if gs.pendingLevelUp {
            gs.screen = .levelUp
        } else if gs.combatReturnScreen == .overworld {
            gs.screen = .overworld
            AmbientAudio.shared.play(.overworld)
        } else {
            gs.checkDungeonCleared()
        }
        gs.randomDMQuote()
    }
}

// MARK: - XP Row

private struct XPRow: View {
    let icon: String
    let name: String
    let role: String
    let xp: Int
    let isPlayer: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 20))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isPlayer ? .white : Color(white: 0.7))
                Text(role)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(white: 0.35))
            }
            Spacer()
            Text("+\(xp) XP")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(isPlayer ? .green : Color(white: 0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isPlayer ? Color.green.opacity(0.06) : Color.clear)
    }
}
