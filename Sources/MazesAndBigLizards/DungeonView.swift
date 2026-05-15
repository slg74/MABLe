import SwiftUI

private let tileSize: CGFloat = 17

struct DungeonView: View {
    @EnvironmentObject var gs: GameState
    @State private var showChestAlert: Bool = false
    @State private var chestMessage: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                DungeonTopBar()

                // DM quote strip
                ScrollView(.horizontal, showsIndicators: false) {
                    Text("🤘 \(gs.dmQuote)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .background(Color(white: 0.05))

                Spacer()

                // Map
                if let dungeon = gs.dungeon {
                    MapGridView(dungeon: dungeon)
                        .padding(.vertical, 8)
                }

                Spacer()

                // Monster list (visible ones)
                if let dungeon = gs.dungeon {
                    let visible = dungeon.monsters.filter { $0.isAlive && dungeon.tiles[$0.position.row][$0.position.col].visible }
                    if !visible.isEmpty {
                        HStack {
                            Text("NEARBY:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(white: 0.35))
                            ForEach(visible) { m in
                                Text("\(m.icon)\(m.name)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(m.isBoss ? .red : .orange)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    }
                }

                // Player HUD
                if let p = gs.player {
                    PlayerHUD(player: p).padding(.horizontal, 16)
                }

                // D-Pad
                DPad { dr, dc in
                    handleMove(dr: dr, dc: dc)
                }
                .padding(.vertical, 16)

                // Quick actions
                HStack(spacing: 12) {
                    Button("🌍 Overworld") { gs.returnToOverworld() }
                        .buttonStyle(MetalButtonStyle(color: Color(white: 0.2)))
                    Button("📋 Sheet") { gs.openCharacterSheet() }
                        .buttonStyle(MetalButtonStyle(color: Color(white: 0.2)))
                    Button("🎲 Wait") {
                        // Waiting restores 1 HP
                        if var p = gs.player, p.currentHP < p.maxHP {
                            p.currentHP += 1
                            gs.player = p
                            gs.flash("💤 Rested. +1 HP")
                        }
                        gs.randomDMQuote()
                    }
                    .buttonStyle(MetalButtonStyle(color: Color(white: 0.2)))
                }
                .padding(.bottom, 24)
            }
        }
        .alert("Chest Found!", isPresented: $showChestAlert) {
            Button("Take It") { }
        } message: {
            Text(chestMessage)
        }
    }

    private func handleMove(dr: Int, dc: Int) {
        guard let dungeon = gs.dungeon else { return }
        let result = dungeon.movePlayer(dr: dr, dc: dc)
        switch result {
        case .moved:
            break
        case .blocked:
            gs.flash("🧱 Blocked!")
        case .combat(let monster):
            gs.initiateCombat(with: monster)
        case .stairs:
            gs.descend()
        case .chest(let loot):
            chestMessage = loot
            showChestAlert = true
            // Apply potion if found
            if loot.contains("Healing"), var p = gs.player {
                let heal = Int.random(in: 1...8)
                p.currentHP = min(p.maxHP, p.currentHP + heal)
                gs.player = p
            }
        }
    }
}

// MARK: - Map Grid

// MARK: - Party sprite inside dungeon

struct DungeonPartySprite: View {
    @EnvironmentObject var gs: GameState

    var leaderIcon: String {
        switch gs.player?.characterClass {
        case .fighter: return "🪖"
        case .mage:    return "🧙"
        case .cleric:  return "🛡"
        case .thief:   return "🗡"
        default:       return "🧑"
        }
    }

    var body: some View {
        ZStack {
            // Torch glow
            Circle()
                .fill(Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.22))
                .frame(width: tileSize * 1.8, height: tileSize * 1.8)

            // Leader — centred, larger
            Text(leaderIcon)
                .font(.system(size: tileSize * 0.80))

            // NPC trio — small, behind and beside leader
            Text("🪓").font(.system(size: 8)).offset(x: -tileSize * 0.42, y:  tileSize * 0.36)
            Text("🧙").font(.system(size: 7)).offset(x:  tileSize * 0.40, y:  tileSize * 0.36)
            Text("⛏").font(.system(size: 7)).offset(x:  0,               y:  tileSize * 0.58)
        }
    }
}

// Viewport: how many dungeon tiles to show at once
private let DGN_VP_COLS = 18
private let DGN_VP_ROWS = 16

struct MapGridView: View {
    @ObservedObject var dungeon: Dungeon

    var body: some View {
        let allCols = Dungeon.cols, allRows = Dungeon.rows
        let pp = dungeon.playerPosition

        // Clamp viewport origin so player stays centred
        let vpC = max(0, min(allCols - DGN_VP_COLS, pp.col - DGN_VP_COLS / 2))
        let vpR = max(0, min(allRows - DGN_VP_ROWS, pp.row - DGN_VP_ROWS / 2))

        let vpW = CGFloat(DGN_VP_COLS) * tileSize
        let vpH = CGFloat(DGN_VP_ROWS) * tileSize

        ZStack(alignment: .topLeading) {
            // ── Tile canvas ──────────────────────────────────────────
            Canvas { ctx, _ in
                for row in vpR..<min(vpR + DGN_VP_ROWS, allRows) {
                    for col in vpC..<min(vpC + DGN_VP_COLS, allCols) {
                        let tile = dungeon.tiles[row][col]
                        guard tile.explored else { continue }

                        let sx = CGFloat(col - vpC) * tileSize
                        let sy = CGFloat(row - vpR) * tileSize
                        let rect = CGRect(x: sx, y: sy, width: tileSize, height: tileSize)

                        let color: Color
                        if tile.visible {
                            switch tile.type {
                            case .wall:     color = Color(red: 0.30, green: 0.28, blue: 0.32)
                            case .floor:    color = Color(red: 0.14, green: 0.12, blue: 0.16)
                            case .door:     color = Color(red: 0.55, green: 0.35, blue: 0.15)
                            case .stairs:   color = Color(red: 0.90, green: 0.80, blue: 0.20)
                            case .chest:    color = Color(red: 0.80, green: 0.55, blue: 0.10)
                            case .entrance: color = Color(red: 0.20, green: 0.60, blue: 0.30)
                            }
                        } else {
                            color = Color(white: tile.type == .wall ? 0.10 : 0.07)
                        }
                        ctx.fill(Path(rect), with: .color(color))

                        if tile.visible && tile.type == .wall {
                            let inner = rect.insetBy(dx: 1, dy: 1)
                            ctx.stroke(Path(inner), with: .color(Color(white: 0.22)), lineWidth: 0.5)
                        }
                    }
                }
            }
            .frame(width: vpW, height: vpH)

            // ── Monsters (only those inside the viewport) ─────────────
            ForEach(dungeon.monsters.filter { $0.isAlive }) { monster in
                let mr = monster.position.row, mc = monster.position.col
                if mr >= vpR && mr < vpR + DGN_VP_ROWS &&
                   mc >= vpC && mc < vpC + DGN_VP_COLS &&
                   dungeon.tiles[mr][mc].visible {
                    Text(monster.isBoss ? "🐉" : monster.icon)
                        .font(.system(size: monster.isBoss ? 14 : 11))
                        .frame(width: tileSize, height: tileSize)
                        .offset(x: CGFloat(mc - vpC) * tileSize,
                                y: CGFloat(mr - vpR) * tileSize)
                }
            }

            // ── Party sprite ──────────────────────────────────────────
            DungeonPartySprite()
                .frame(width: tileSize * 2, height: tileSize * 2)
                .offset(x: CGFloat(pp.col - vpC) * tileSize - tileSize * 0.5,
                        y: CGFloat(pp.row - vpR) * tileSize - tileSize * 0.5)

            // ── Legend pinned to bottom of viewport ───────────────────
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    LegendItem(color: .yellow, symbol: "▼", label: "Stairs")
                    LegendItem(color: .orange, symbol: "■", label: "Chest")
                    LegendItem(color: .green,  symbol: "■", label: "Entry")
                }
                .padding(4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
            }
            .frame(width: vpW, height: vpH)
        }
        .frame(width: vpW, height: vpH)
        .clipped()
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.2), lineWidth: 1))
    }
}

struct LegendItem: View {
    let color: Color
    let symbol: String
    let label: String

    var body: some View {
        HStack(spacing: 2) {
            Text(symbol)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
        }
    }
}

// MARK: - D-Pad

struct DPad: View {
    let onMove: (Int, Int) -> Void

    var body: some View {
        VStack(spacing: 2) {
            DPadButton(label: "▲") { onMove(-1, 0) }
            HStack(spacing: 2) {
                DPadButton(label: "◀") { onMove(0, -1) }
                DPadButton(label: "·", isCenter: true) { }
                DPadButton(label: "▶") { onMove(0, 1) }
            }
            DPadButton(label: "▼") { onMove(1, 0) }
        }
    }
}

struct DPadButton: View {
    let label: String
    var isCenter: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isCenter ? Color(white: 0.3) : .white)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isCenter ? Color(white: 0.1) : Color(white: 0.16))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(white: 0.28), lineWidth: 1))
                )
        }
        .disabled(isCenter)
    }
}

// MARK: - Top Bar

struct DungeonTopBar: View {
    @EnvironmentObject var gs: GameState

    var body: some View {
        HStack {
            Button("⬅ World") { gs.returnToOverworld() }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white: 0.5))

            Spacer()

            Text("DUNGEON LEVEL \(gs.dungeonLevel)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)

            Spacer()

            if let d = gs.dungeon {
                let alive = d.monsters.filter { $0.isAlive }.count
                Text("👹 ×\(alive)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.red)
            }
            MusicToggleButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.06))
    }
}
