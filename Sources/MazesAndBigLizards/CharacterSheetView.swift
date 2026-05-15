import SwiftUI

private let allWeapons: [Weapon] = [.dagger, .shortSword, .mace, .longsword, .battleaxe, .twoHander]

struct CharacterSheetView: View {
    @EnvironmentObject var gs: GameState
    @State private var viewingIndex: Int? = nil   // nil = player, 0/1/2 = npc

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.03, blue: 0.08),
                                    Color(red: 0.08, green: 0.05, blue: 0.12),
                                    Color(red: 0.04, green: 0.03, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Top bar
                    HStack {
                        if viewingIndex == nil {
                            Button("⬅ Back") { gs.screen = gs.charSheetReturn }
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(white: 0.5))
                        } else {
                            Button("⬅ Back") { viewingIndex = nil }
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(white: 0.5))
                        }

                        Spacer()

                        if let idx = viewingIndex {
                            Text(npcParty[idx].name.uppercased())
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(npcParty[idx].color.opacity(0.9))
                                .tracking(2)
                        } else {
                            Text("CHARACTER SHEET")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(Color(white: 0.6))
                                .tracking(2)
                        }

                        Spacer()

                        if let idx = viewingIndex {
                            if idx < npcParty.count - 1 {
                                Button("Next ›") { viewingIndex = idx + 1 }
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(white: 0.5))
                            } else {
                                // Back to player
                                Button("Player ›") { viewingIndex = nil }
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(white: 0.5))
                            }
                        } else {
                            Button("Party ›") { viewingIndex = 0 }
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.06))

                    if let idx = viewingIndex {
                        PartyMemberSheetView(member: npcParty[idx])
                            .transition(.opacity)
                    } else if let p = gs.player {
                        VStack(spacing: 12) {
                            CharacterPortrait(player: p)
                                .padding(.top, 12)

                            VStack(spacing: 8) {
                                HPBar(current: p.currentHP, max: p.maxHP)
                                XPBar(current: p.experience, next: p.nextLevelXP)
                            }
                            .padding(.horizontal, 16)

                            HStack(spacing: 0) {
                                CombatStatTile(label: "AC", value: "\(p.armorClass)", color: .cyan)
                                Divider().frame(width: 1).background(Color(white: 0.18))
                                CombatStatTile(label: "THAC0", value: "\(p.thac0)", color: .orange)
                                Divider().frame(width: 1).background(Color(white: 0.18))
                                CombatStatTile(label: "LEVEL", value: "\(p.level)", color: .yellow)
                                Divider().frame(width: 1).background(Color(white: 0.18))
                                CombatStatTile(label: "HP MAX", value: "\(p.maxHP)", color: .green)
                            }
                            .background(Color(white: 0.07))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.16), lineWidth: 1))
                            .padding(.horizontal, 16)

                            AbilityScoreGrid(player: p)
                                .padding(.horizontal, 16)

                            WeaponLoadout(player: p) { weapon in
                                if var updated = gs.player {
                                    updated.weapon = weapon
                                    gs.player = updated
                                }
                            }
                            .padding(.horizontal, 16)

                            ArmorPanel(player: p)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewingIndex)
    }
}

// MARK: - Party Member Sheet

struct PartyMemberSheetView: View {
    let member: PartyMember

    var body: some View {
        VStack(spacing: 12) {
            // Portrait
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(member.color.opacity(0.15))
                        .frame(width: 110, height: 110)
                    Circle()
                        .strokeBorder(member.color.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 106, height: 106)
                    Text(member.icon)
                        .font(.system(size: 54))
                }
                Text(member.name)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text(member.role)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(member.color.opacity(0.8))
                Text("\"\(member.quote)\"")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 12)

            // HP bar (always full for NPCs)
            HPBar(current: member.maxHP, max: member.maxHP)
                .padding(.horizontal, 16)

            // Combat stats
            HStack(spacing: 0) {
                CombatStatTile(label: "AC",    value: "\(member.armorClass)", color: .cyan)
                Rectangle().fill(Color(white: 0.18)).frame(width: 1).padding(.vertical, 4)
                CombatStatTile(label: "THAC0", value: "\(member.thac0)",      color: .orange)
                Rectangle().fill(Color(white: 0.18)).frame(width: 1).padding(.vertical, 4)
                CombatStatTile(label: "HP",    value: "\(member.maxHP)",      color: .green)
            }
            .background(Color(white: 0.07))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.16), lineWidth: 1))
            .padding(.horizontal, 16)

            // Weapon
            VStack(spacing: 8) {
                Text("WEAPON")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.35))
                    .tracking(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Text(member.weaponIcon).font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.weaponName)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        let die = member.damageBonus > 0
                            ? "1d\(member.damageDie)+\(member.damageBonus)"
                            : "1d\(member.damageDie)"
                        Text(die)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(white: 0.07))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.18), lineWidth: 1))
            }
            .padding(.horizontal, 16)

            // Bio
            Text(member.bio)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white: 0.45))
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Portrait

struct CharacterPortrait: View {
    let player: Character

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Glow
                Circle()
                    .fill(player.characterClass.color.opacity(0.15))
                    .frame(width: 110, height: 110)
                Circle()
                    .strokeBorder(player.characterClass.color.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 106, height: 106)

                Text(player.characterClass.icon)
                    .font(.system(size: 54))
            }

            Text(player.name)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Text(player.race.icon)
                Text("Level \(player.level) \(player.race.rawValue) \(player.characterClass.rawValue)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(player.characterClass.color.opacity(0.8))
            }

            Text(player.characterClass.classDescription)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - XP Bar

struct XPBar: View {
    let current: Int
    let next: Int

    var fraction: Double { min(1.0, Double(current) / Double(next)) }

    var body: some View {
        HStack(spacing: 6) {
            Text("XP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.12)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)
            Text("\(current)/\(next)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(white: 0.45))
        }
    }
}

// MARK: - Combat Stat Tile

struct CombatStatTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.38))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Ability Scores

struct AbilityScoreGrid: View {
    let player: Character

    var body: some View {
        VStack(spacing: 6) {
            Text("ABILITY SCORES")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.35))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                AbilityTile(label: "STR", value: player.strength, bonus: player.strBonus)
                divider()
                AbilityTile(label: "DEX", value: player.dexterity, bonus: player.dexBonus)
                divider()
                AbilityTile(label: "CON", value: player.constitution, bonus: (player.constitution-10)/2)
            }
            .background(Color(white: 0.07)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.15), lineWidth: 1))

            HStack(spacing: 0) {
                AbilityTile(label: "INT", value: player.intelligence, bonus: (player.intelligence-10)/2)
                divider()
                AbilityTile(label: "WIS", value: player.wisdom, bonus: (player.wisdom-10)/2)
                divider()
                AbilityTile(label: "CHA", value: player.charisma, bonus: (player.charisma-10)/2)
            }
            .background(Color(white: 0.07)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.15), lineWidth: 1))
        }
    }

    private func divider() -> some View {
        Rectangle().fill(Color(white: 0.14)).frame(width: 1).padding(.vertical, 4)
    }
}

struct AbilityTile: View {
    let label: String
    let value: Int
    let bonus: Int

    var bonusStr: String { bonus >= 0 ? "+\(bonus)" : "\(bonus)" }
    var bonusColor: Color { bonus > 0 ? .green : bonus < 0 ? .red : Color(white: 0.4) }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.38))
            Text("\(value)")
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text(bonusStr)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(bonusColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Weapon Loadout

struct WeaponLoadout: View {
    let player: Character
    let onEquip: (Weapon) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("WEAPONS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.35))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Currently equipped — larger display
            HStack(spacing: 10) {
                Text(player.weapon.icon).font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.weapon.name)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    let die = player.weapon.damageBonus > 0
                        ? "1d\(player.weapon.damageDie)+\(player.weapon.damageBonus)"
                        : "1d\(player.weapon.damageDie)"
                    Text(die)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("EQUIPPED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(4)
            }
            .padding(12)
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.4), lineWidth: 1.5))

            // Weapon picker grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(allWeapons, id: \.name) { weapon in
                    let equipped = weapon.name == player.weapon.name
                    Button { if !equipped { onEquip(weapon) } } label: {
                        HStack(spacing: 8) {
                            Text(weapon.icon).font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(weapon.name)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(equipped ? .green : .white)
                                    .lineLimit(1)
                                let die = weapon.damageBonus > 0
                                    ? "1d\(weapon.damageDie)+\(weapon.damageBonus)"
                                    : "1d\(weapon.damageDie)"
                                Text(die)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            if equipped {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(equipped ? Color.green.opacity(0.12) : Color(white: 0.08))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(equipped ? Color.green.opacity(0.5) : Color(white: 0.18), lineWidth: equipped ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Armor Panel

struct ArmorPanel: View {
    let player: Character

    var armorDescription: String {
        switch player.armorClass {
        case ..<0: return "Enchanted plate — legendary protection"
        case 0...2: return "Full plate armor"
        case 3...4: return "Chain mail + shield"
        case 5...6: return "Chain mail or plate"
        case 7...8: return "Leather armor"
        default:    return "No armor (robes / traveling clothes)"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("ARMOR")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.35))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(player.armorClass)")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("ARMOR CLASS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(armorDescription)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                    Text("Lower AC = harder to hit")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(white: 0.3))
                    if player.dexBonus != 0 {
                        Text("DEX bonus: \(player.dexBonus >= 0 ? "+\(player.dexBonus)" : "\(player.dexBonus)") applied")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(player.dexBonus > 0 ? .green : .red)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Color(white: 0.07))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
        }
    }
}
