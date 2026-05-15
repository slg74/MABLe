import Foundation
import SwiftUI

// MARK: - Tile

enum OWTileType: Equatable {
    case grass, forest, mountain, water, road
    case town, castle, dungeon(Int)   // dungeon difficulty 1-3

    var walkable: Bool {
        switch self { case .mountain, .water: return false; default: return true }
    }

    var baseColor: Color {
        switch self {
        case .grass:       return Color(red: 0.18, green: 0.52, blue: 0.12)
        case .forest:      return Color(red: 0.05, green: 0.28, blue: 0.05)
        case .mountain:    return Color(red: 0.42, green: 0.38, blue: 0.32)
        case .water:       return Color(red: 0.04, green: 0.14, blue: 0.48)
        case .road:        return Color(red: 0.52, green: 0.43, blue: 0.22)
        case .town:        return Color(red: 0.32, green: 0.22, blue: 0.52)
        case .castle:      return Color(red: 0.48, green: 0.44, blue: 0.38)
        case .dungeon:     return Color(red: 0.22, green: 0.08, blue: 0.08)
        }
    }

    var dimColor: Color { baseColor.opacity(0.35) }

    var icon: String? {
        switch self {
        case .forest:   return "🌲"
        case .mountain: return "🗻"
        case .water:    return nil
        case .town:     return "🏘"
        case .castle:   return "🏰"
        case .dungeon:  return "🕳"
        default:        return nil
        }
    }
}

struct OWCell {
    var type: OWTileType = .grass
    var explored: Bool   = false
    var visible: Bool    = false
}

// MARK: - Location

struct OWLocation: Identifiable {
    let id        = UUID()
    let name: String
    let position: GridPosition
    let type: OWTileType
    let dmQuote: String
}

// MARK: - Map

class OverworldMap: ObservableObject {
    static let width  = 40
    static let height = 30

    @Published var cells: [[OWCell]]
    @Published var playerPos: GridPosition

    private(set) var locations: [OWLocation] = []

    init(startPos: GridPosition = GridPosition(row: 18, col: 10)) {
        let w = OverworldMap.width, h = OverworldMap.height
        cells = Array(repeating: Array(repeating: OWCell(), count: w), count: h)
        playerPos = startPos
        build()
        updateVisibility()
    }

    // MARK: Build world

    private func build() {
        let w = OverworldMap.width, h = OverworldMap.height

        // ── Water border ───────────────────────────────────
        for r in 0..<h { for c in 0..<w {
            if r < 2 || r >= h-2 || c < 2 || c >= w-2 { set(r, c, .water) }
        }}

        // ── NW mountain range ──────────────────────────────
        fill(rows: 2...9,  cols: 2...7,  .mountain)
        fill(rows: 2...5,  cols: 8...10, .mountain)
        fill(rows: 6...8,  cols: 8...9,  .mountain)

        // ── West forest ────────────────────────────────────
        fill(rows: 7...14, cols: 2...6,  .forest)
        fill(rows: 9...12, cols: 7...8,  .forest)

        // ── NE forest (near Dragon's Peak) ─────────────────
        fill(rows: 3...9,  cols: 33...37, .forest)
        fill(rows: 5...8,  cols: 30...32, .forest)

        // ── SE forest (near Darkstone Mines) ───────────────
        fill(rows: 19...25, cols: 28...37, .forest)
        fill(rows: 22...26, cols: 24...27, .forest)

        // ── Central lake ───────────────────────────────────
        fill(rows: 13...18, cols: 23...28, .water)
        fill(rows: 14...17, cols: 22...22, .water)

        // ── Roads ──────────────────────────────────────────
        for r in 5...19 { set(r, 14, .road) }        // N-S spine
        for c in 8...20 { set(5,  c, .road) }        // E-W upper
        for c in 8...13 { set(18, c, .road) }        // E-W to village

        // ── Named locations ────────────────────────────────
        place(name: "Thornwall",
              type: .town,   row: 18, col: 8,
              dm: "Thornwall — your home base. The inn serves warm ale and suspicious stew. Rest up.")

        place(name: "King's Redoubt",
              type: .castle, row: 5, col: 20,
              dm: "King's Redoubt. His Majesty wants the Big Lizard dead. He's offering gold. You need gold.")

        place(name: "Forest of Gloom",
              type: .dungeon(1), row: 9, col: 4,
              dm: "Forest of Gloom — Level 1 dungeon. Goblins mostly. Good warm-up. Don't die.")

        place(name: "Darkstone Mines",
              type: .dungeon(2), row: 22, col: 30,
              dm: "Darkstone Mines — Level 2. Trolls. Zombies. The miners are definitely gone. Gear up first.")

        place(name: "Dragon's Peak",
              type: .dungeon(3), row: 6, col: 36,
              dm: "Dragon's Peak — the Big Lizard's lair. You are NOT ready for this. ...You're going anyway, aren't you.")
    }

    private func set(_ r: Int, _ c: Int, _ type: OWTileType) {
        guard r >= 0 && r < OverworldMap.height, c >= 0 && c < OverworldMap.width else { return }
        cells[r][c].type = type
    }

    private func fill(rows: ClosedRange<Int>, cols: ClosedRange<Int>, _ type: OWTileType) {
        for r in rows { for c in cols { set(r, c, type) } }
    }

    private func place(name: String, type: OWTileType, row: Int, col: Int, dm: String) {
        set(row, col, type)
        locations.append(OWLocation(name: name, position: GridPosition(row: row, col: col), type: type, dmQuote: dm))
    }

    // MARK: Movement

    enum MoveOutcome {
        case moved
        case blocked
        case enteredLocation(OWLocation)
    }

    func movePlayer(dr: Int, dc: Int) -> MoveOutcome {
        let next = playerPos.offset(dr: dr, dc: dc)
        guard next.row >= 0 && next.row < OverworldMap.height,
              next.col >= 0 && next.col < OverworldMap.width else { return .blocked }
        guard cells[next.row][next.col].type.walkable else { return .blocked }

        playerPos = next
        updateVisibility()

        if let loc = locations.first(where: { $0.position == next }) {
            return .enteredLocation(loc)
        }
        return .moved
    }

    // MARK: Visibility (fog of war — generous on overworld)

    func updateVisibility() {
        let radius = 6
        let pr = playerPos.row, pc = playerPos.col
        for r in 0..<OverworldMap.height {
            for c in 0..<OverworldMap.width {
                cells[r][c].visible = false
            }
        }
        for r in max(0, pr-radius)...min(OverworldMap.height-1, pr+radius) {
            for c in max(0, pc-radius)...min(OverworldMap.width-1, pc+radius) {
                cells[r][c].visible  = true
                cells[r][c].explored = true
            }
        }
    }

    // Nearest unvisited location (for DM hints)
    func nearestLocation(to pos: GridPosition, within radius: Int) -> OWLocation? {
        locations.filter { loc in
            abs(loc.position.row - pos.row) + abs(loc.position.col - pos.col) <= radius
        }
        .min { a, b in
            let da = abs(a.position.row - pos.row) + abs(a.position.col - pos.col)
            let db = abs(b.position.row - pos.row) + abs(b.position.col - pos.col)
            return da < db
        }
    }
}
