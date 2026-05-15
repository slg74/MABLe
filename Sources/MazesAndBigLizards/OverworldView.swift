import SwiftUI

// Tile size and viewport constants
private let OW_TILE: CGFloat = 24
private let OW_COLS = 16   // tiles visible horizontally
private let OW_ROWS = 14   // tiles visible vertically

struct OverworldView: View {
    @EnvironmentObject var gs: GameState
    @State private var showLocationAlert = false
    @State private var pendingLocation: OWLocation? = nil
    @State private var torchFlicker = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.05, blue: 0.02).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar ────────────────────────────────────────────
                OverworldTopBar()

                // ── DM quote ───────────────────────────────────────────
                HStack(spacing: 6) {
                    Text("🤘")
                    Text(gs.dmQuote)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.55))
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.04))

                Spacer()

                // ── Map viewport ───────────────────────────────────────
                if let ow = gs.overworldMap {
                    OverworldMapView(map: ow)
                        .frame(width: CGFloat(OW_COLS) * OW_TILE,
                               height: CGFloat(OW_ROWS) * OW_TILE)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(white: 0.2), lineWidth: 1))
                }

                Spacer()

                // ── Location legend strip ──────────────────────────────
                if let ow = gs.overworldMap {
                    LocationLegend(locations: ow.locations, playerPos: ow.playerPos)
                        .padding(.horizontal, 12)
                }

                // ── Player HUD ─────────────────────────────────────────
                if let p = gs.player {
                    PlayerHUD(player: p).padding(.horizontal, 16).padding(.top, 6)
                }

                // ── D-Pad + actions ────────────────────────────────────
                HStack(alignment: .center, spacing: 24) {
                    DPad { dr, dc in handleMove(dr: dr, dc: dc) }

                    VStack(spacing: 8) {
                        Button("🏠 Rest\n+1 HP") {
                            if var p = gs.player, p.currentHP < p.maxHP {
                                p.currentHP = min(p.maxHP, p.currentHP + Int.random(in: 1...4))
                                gs.player = p
                                gs.flash("💤 Rested. HP restored.")
                            }
                            gs.randomDMQuote()
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .buttonStyle(MetalButtonStyle(color: Color(white: 0.2)))

                        Button("🗺️ Table") { gs.screen = .tableScene }
                            .font(.system(size: 11, design: .monospaced))
                            .buttonStyle(MetalButtonStyle(color: Color(white: 0.2)))

                        Button("📋 Sheet") { gs.openCharacterSheet() }
                            .font(.system(size: 11, design: .monospaced))
                            .buttonStyle(MetalButtonStyle(color: Color(white: 0.2)))
                    }
                }
                .padding(.vertical, 14)
                .padding(.bottom, 10)
            }
        }
        .alert(pendingLocation?.name ?? "", isPresented: $showLocationAlert) {
            if let loc = pendingLocation {
                switch loc.type {
                case .dungeon(let diff):
                    Button("Enter (Difficulty \(diff))") {
                        gs.enterDungeonAt(difficulty: diff, name: loc.name)
                    }
                    Button("Not yet", role: .cancel) { }
                default:
                    Button("OK", role: .cancel) { }
                }
            }
        } message: {
            Text(pendingLocation?.dmQuote ?? "")
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in torchFlicker.toggle() }
        }
    }

    private func handleMove(dr: Int, dc: Int) {
        guard let ow = gs.overworldMap else { return }
        let result = ow.movePlayer(dr: dr, dc: dc)
        switch result {
        case .moved:
            // Proximity DM hint
            if Int.random(in: 1...8) == 1 {
                if let nearby = ow.nearestLocation(to: ow.playerPos, within: 7) {
                    gs.dmQuote = nearby.dmQuote
                } else {
                    gs.randomDMQuote()
                }
            }
            // Random encounter roll
            checkEncounter(terrain: ow.cells[ow.playerPos.row][ow.playerPos.col].type)

        case .blocked:
            break

        case .enteredLocation(let loc):
            pendingLocation = loc
            gs.dmQuote = loc.dmQuote
            showLocationAlert = true
        }
    }

    // ── Random encounter ──────────────────────────────────────────────────
    private func checkEncounter(terrain: OWTileType) {
        let pct: Int
        switch terrain {
        case .forest: pct = 22
        case .road:   pct = 5
        case .grass:  pct = 11
        default:      return          // towns, castles, dungeons, water — no roaming mobs
        }
        guard Int.random(in: 1...100) <= pct else { return }

        let level = gs.player?.level ?? 1
        let monster: Monster
        switch level {
        case 1...2:  monster = Bool.random() ? Monster.makeGoblin()   : Monster.makeSkeleton()
        case 3...4:  monster = Bool.random() ? Monster.makeOrc()       : Monster.makeZombie()
        case 5...6:  monster = Bool.random() ? Monster.makeZombie()    : Monster.makeOrc()
        default:     monster = Bool.random() ? Monster.makeTroll()     : Monster.makeOrc()
        }

        let terrainName: String
        switch terrain {
        case .forest: terrainName = "in the forest"
        case .road:   terrainName = "on the road"
        default:      terrainName = "in the open"
        }

        gs.flash("⚠️  A \(monster.name) lunges at you \(terrainName)!")
        gs.dmQuote = "Random encounter! A \(monster.name)! Roll initiative — which you already did because I decided it for you."

        // Brief delay so the flash reads before the screen flips
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            gs.initiateCombat(with: monster, returnTo: .overworld)
        }
    }
}

// MARK: - Map Canvas

struct OverworldMapView: View {
    @ObservedObject var map: OverworldMap
    @EnvironmentObject var gs: GameState

    var body: some View {
        let cols = OverworldMap.width, rows = OverworldMap.height
        let pp = map.playerPos

        // Viewport origin clamped so player is as centred as possible
        let vpC = max(0, min(cols - OW_COLS, pp.col - OW_COLS / 2))
        let vpR = max(0, min(rows - OW_ROWS, pp.row - OW_ROWS / 2))

        ZStack(alignment: .topLeading) {
            // Terrain canvas
            Canvas { ctx, _ in
                for row in vpR..<(vpR + OW_ROWS) {
                    for col in vpC..<(vpC + OW_COLS) {
                        let cell = map.cells[row][col]
                        let sx = CGFloat(col - vpC) * OW_TILE
                        let sy = CGFloat(row - vpR) * OW_TILE
                        let rect = CGRect(x: sx, y: sy, width: OW_TILE, height: OW_TILE)

                        let color = cell.visible  ? cell.type.baseColor
                                  : cell.explored ? cell.type.dimColor
                                  : .black

                        ctx.fill(Path(rect), with: .color(color))

                        // Subtle grid lines on walkable tiles
                        if cell.visible && cell.type != .water {
                            ctx.stroke(Path(rect), with: .color(Color(white: 0.0, opacity: 0.25)), lineWidth: 0.4)
                        }
                    }
                }
            }

            // Icons overlay
            ForEach(vpR..<min(vpR + OW_ROWS, rows), id: \.self) { row in
                ForEach(vpC..<min(vpC + OW_COLS, cols), id: \.self) { col in
                    let cell = map.cells[row][col]
                    if cell.visible, let icon = cell.type.icon {
                        Text(icon)
                            .font(.system(size: OW_TILE * 0.62))
                            .frame(width: OW_TILE, height: OW_TILE)
                            .offset(x: CGFloat(col - vpC) * OW_TILE,
                                    y: CGFloat(row - vpR) * OW_TILE)
                    }
                }
            }

            // Location name labels (for explored special tiles)
            ForEach(map.locations) { loc in
                let lc = loc.position.col, lr = loc.position.row
                if lc >= vpC && lc < vpC + OW_COLS && lr >= vpR && lr < vpR + OW_ROWS {
                    let cell = map.cells[lr][lc]
                    if cell.explored {
                        Text(loc.name)
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                            .frame(width: OW_TILE * 3.5)
                            .offset(x: CGFloat(lc - vpC) * OW_TILE - OW_TILE * 1.25,
                                    y: CGFloat(lr - vpR) * OW_TILE + OW_TILE)
                    }
                }
            }

            // Party cluster on player tile
            PartySprite(player: gs.player)
                .frame(width: OW_TILE, height: OW_TILE)
                .offset(x: CGFloat(pp.col - vpC) * OW_TILE,
                        y: CGFloat(pp.row - vpR) * OW_TILE)
        }
        .frame(width: CGFloat(OW_COLS) * OW_TILE, height: CGFloat(OW_ROWS) * OW_TILE)
        .clipped()
    }
}

// MARK: - Party Sprite

struct PartySprite: View {
    let player: Character?

    var leaderIcon: String {
        switch player?.characterClass {
        case .fighter: return "🪖"
        case .mage:    return "🧙"
        case .cleric:  return "🛡"
        case .thief:   return "🗡"
        default:       return "🧑"
        }
    }

    var body: some View {
        ZStack {
            // Glow under party
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: OW_TILE * 0.9, height: OW_TILE * 0.9)

            // Leader front-centre
            Text(leaderIcon)
                .font(.system(size: OW_TILE * 0.72))

            // NPC followers — small icons, triangle formation behind
            Group {
                Text("🪓").font(.system(size: 8))
                    .offset(x: -OW_TILE * 0.34, y: OW_TILE * 0.30)
                Text("🧙").font(.system(size: 7))
                    .offset(x:  OW_TILE * 0.32, y: OW_TILE * 0.30)
                Text("⛏").font(.system(size: 7))
                    .offset(x:  0,              y: OW_TILE * 0.48)
            }
        }
    }
}

// MARK: - Location Legend

struct LocationLegend: View {
    let locations: [OWLocation]
    let playerPos: GridPosition

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(locations) { loc in
                    let dist = abs(loc.position.row - playerPos.row) + abs(loc.position.col - playerPos.col)
                    let color: Color = {
                        switch loc.type {
                        case .town:        return .purple
                        case .castle:      return .yellow
                        case .dungeon(1):  return Color(red: 0.6, green: 0.3, blue: 0.1)
                        case .dungeon(2):  return .orange
                        case .dungeon(3):  return .red
                        default:           return .gray
                        }
                    }()
                    HStack(spacing: 3) {
                        Text(loc.type.icon ?? "·")
                            .font(.system(size: 12))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(loc.name)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(color)
                            Text("\(dist) tiles")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(Color(white: 0.35))
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(color.opacity(0.35), lineWidth: 1))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Top Bar

struct OverworldTopBar: View {
    @EnvironmentObject var gs: GameState

    var body: some View {
        HStack {
            Text("🌍 OVERWORLD")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.green)
            Spacer()
            if let p = gs.player {
                Text("\(p.characterClass.icon) Lvl \(p.level)  XP:\(p.experience)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
            }
            MusicToggleButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.05))
    }
}
