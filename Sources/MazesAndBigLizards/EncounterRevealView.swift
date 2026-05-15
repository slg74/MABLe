import SwiftUI

private enum EncounterPhase { case reveal, rolling, result }

struct EncounterRevealView: View {
    @EnvironmentObject var gs: GameState

    @State private var phase: EncounterPhase = .reveal
    @State private var playerRoll: Int = 20
    @State private var isRolling: Bool = false
    @State private var displayedRoll: Int = 20
    @State private var dmArmRaised: Bool = false
    @State private var monsterVisible: Bool = false

    var monster: Monster { gs.pendingMonster ?? Monster.makeGoblin() }
    var dexBonus: Int { gs.player.map { ($0.dexterity - 10) / 2 } ?? 0 }
    var playerTotal: Int { playerRoll + dexBonus }
    var monsterRoll: Int { gs.encounterMonsterInitiative }
    var playerWins: Bool { playerTotal >= monsterRoll }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.03, blue: 0.07),
                                    Color(red: 0.10, green: 0.06, blue: 0.12),
                                    Color(red: 0.04, green: 0.03, blue: 0.07)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ─────────────────────────────────────────────
                HStack {
                    Text("⚠️  ENCOUNTER")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                    Spacer()
                    Text("LVL \(monster.level)  \(monster.icon)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.18, green: 0.03, blue: 0.03))

                if phase == .reveal {
                    revealPhase
                } else {
                    initiativePhase
                }
            }
        }
        .onAppear {
            withAnimation(.spring().delay(0.3)) { dmArmRaised = true }
            withAnimation(.easeIn(duration: 0.5).delay(0.6)) { monsterVisible = true }
        }
    }

    // MARK: - Reveal phase

    private var revealPhase: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── DM table cutback ───────────────────────────────────
                VStack(spacing: 6) {
                    Text("⚡️  DAEMON  •  DUNGEON MASTER  ⚡️")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.3))
                        .tracking(2)

                    DMView(armRaised: dmArmRaised)
                        .frame(width: 100, height: 110)

                    DMSpeechBubble(text: monster.encounterLine.isEmpty
                                   ? "From the darkness… something stirs."
                                   : monster.encounterLine)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)

                // ── Monster reveal card ────────────────────────────────
                VStack(spacing: 8) {
                    Text(monster.icon)
                        .font(.system(size: monster.isBoss ? 72 : 56))
                        .shadow(color: monster.isBoss ? .red.opacity(0.9) : .orange.opacity(0.6),
                                radius: monster.isBoss ? 24 : 14)
                        .scaleEffect(monsterVisible ? 1.0 : 0.3)
                        .opacity(monsterVisible ? 1.0 : 0.0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: monsterVisible)

                    Text(monster.name)
                        .font(.system(size: monster.isBoss ? 20 : 16, weight: .black, design: .monospaced))
                        .foregroundColor(monster.isBoss ? .red : .orange)

                    Text(monster.flavor)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    HStack(spacing: 16) {
                        monsterStat(label: "HP", value: "\(monster.currentHP)")
                        monsterStat(label: "AC", value: "\(monster.armorClass)")
                        monsterStat(label: "THAC0", value: "\(monster.thac0)")
                        monsterStat(label: "DMG", value: "1d\(monster.damageDie)\(monster.damageBonus > 0 ? "+\(monster.damageBonus)" : "")")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(white: 0.07))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(monster.isBoss ? Color.red.opacity(0.4) : Color.orange.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
                .background(Color(white: 0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(monster.isBoss ? Color.red.opacity(0.5) : Color(white: 0.15), lineWidth: 1))
                .padding(.horizontal, 16)
                .opacity(monsterVisible ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.4).delay(0.2), value: monsterVisible)

                Spacer(minLength: 20)

                // ── Initiative button ──────────────────────────────────
                Button("🎲  ROLL FOR INITIATIVE") {
                    startInitiativeRoll()
                }
                .buttonStyle(MetalButtonStyle(color: Color(red: 0.5, green: 0.1, blue: 0.6)))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .opacity(monsterVisible ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.3).delay(0.5), value: monsterVisible)
            }
        }
    }

    // MARK: - Initiative phase

    private var initiativePhase: some View {
        VStack(spacing: 20) {
            Text("🎲 INITIATIVE")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top, 24)

            // Two dice side by side
            HStack(spacing: 24) {
                // Player die
                VStack(spacing: 6) {
                    Text("YOU")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                        .tracking(2)
                    DiceDisplay(value: displayedRoll, sides: 20, isRolling: isRolling)
                        .frame(width: 140)
                    if !isRolling && phase == .result {
                        let bonus = dexBonus
                        Text(bonus != 0 ? "\(displayedRoll) \(bonus > 0 ? "+" : "")\(bonus) DEX = \(playerTotal)" : "= \(playerTotal)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                }

                Text("VS")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(Color(white: 0.3))

                // Monster die
                VStack(spacing: 6) {
                    Text(monster.icon)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                        .tracking(2)
                    DiceDisplay(value: phase == .result ? monsterRoll : 20,
                                sides: 20, isRolling: false)
                        .frame(width: 140)
                        .opacity(phase == .result ? 1.0 : 0.3)
                    if phase == .result {
                        Text("= \(monsterRoll)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 16)

            // Result banner
            if phase == .result {
                VStack(spacing: 6) {
                    Text(playerWins ? "✅  YOU GO FIRST" : "💀  MONSTER GOES FIRST")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(playerWins ? .green : .red)

                    Text(playerWins
                         ? "Strike before it can react!"
                         : "Brace yourself. It's already moving.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.45))
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(playerWins ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(playerWins ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))

                Button("⚔️  BEGIN COMBAT") {
                    gs.beginCombat(monsterFirst: !playerWins)
                }
                .buttonStyle(MetalButtonStyle(color: playerWins
                                              ? Color(red: 0.1, green: 0.4, blue: 0.1)
                                              : Color(red: 0.5, green: 0.05, blue: 0.05)))
                .padding(.horizontal, 24)
                .transition(.opacity)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func monsterStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(white: 0.35))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private func startInitiativeRoll() {
        phase = .rolling
        isRolling = true
        playerRoll = Int.random(in: 1...20)

        let delays: [Double] = [0.04,0.04,0.05,0.05,0.06,0.07,0.09,0.11,0.14,0.18,0.23,0.30]
        var tick = 0
        func step() {
            guard tick < delays.count else {
                displayedRoll = playerRoll
                isRolling = false
                withAnimation(.spring()) { phase = .result }
                return
            }
            displayedRoll = Int.random(in: 1...20)
            let d = delays[tick]; tick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + d) { step() }
        }
        step()
    }
}
