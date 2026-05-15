import Foundation
import SwiftUI

class Dungeon: ObservableObject {
    static let cols = 22
    static let rows = 22

    @Published var tiles: [[DungeonTile]]
    @Published var playerPosition: GridPosition
    @Published var monsters: [Monster]

    private(set) var rooms: [(row: Int, col: Int, h: Int, w: Int)] = []
    let difficulty: Int   // 1 = easy, 2 = medium, 3 = hard (Big Lizard)

    init(difficulty: Int = 1) {
        self.difficulty = difficulty
        tiles = Array(repeating: Array(repeating: DungeonTile(), count: Dungeon.cols), count: Dungeon.rows)
        playerPosition = GridPosition(row: 1, col: 1)
        monsters = []
        generate()
    }

    func generate() {
        tiles = Array(repeating: Array(repeating: DungeonTile(), count: Dungeon.cols), count: Dungeon.rows)
        monsters = []
        rooms = []

        var attempts = 0
        while rooms.count < 8 && attempts < 200 {
            attempts += 1
            let h = Int.random(in: 3...6)
            let w = Int.random(in: 4...8)
            let r = Int.random(in: 1...(Dungeon.rows - h - 2))
            let c = Int.random(in: 1...(Dungeon.cols - w - 2))
            let candidate = (row: r, col: c, h: h, w: w)

            let overlaps = rooms.contains {
                r < $0.row + $0.h + 1 && r + h > $0.row - 1 &&
                c < $0.col + $0.w + 1 && c + w > $0.col - 1
            }
            guard !overlaps else { continue }

            rooms.append(candidate)
            for row in r..<(r + h) {
                for col in c..<(c + w) {
                    tiles[row][col].type = .floor
                }
            }
        }

        // Corridors
        for i in 1..<rooms.count {
            let a = rooms[i - 1], b = rooms[i]
            let ar = a.row + a.h / 2, ac = a.col + a.w / 2
            let br = b.row + b.h / 2, bc = b.col + b.w / 2
            for col in min(ac, bc)...max(ac, bc) { tiles[ar][col].type = .floor }
            for row in min(ar, br)...max(ar, br) { tiles[row][bc].type = .floor }
        }

        // Entrance
        if let first = rooms.first {
            playerPosition = GridPosition(row: first.row + 1, col: first.col + 1)
            tiles[playerPosition.row][playerPosition.col].type = .entrance
        }

        // Stairs in last room
        if let last = rooms.last {
            let sr = last.row + last.h / 2, sc = last.col + last.w / 2
            tiles[sr][sc].type = .stairs
        }

        // Chests
        for room in rooms.dropFirst().prefix(4) {
            tiles[room.row + 1][room.col + room.w - 2].type = .chest
        }

        // Monsters — pool depends on difficulty
        let pool: [() -> Monster]
        switch difficulty {
        case 1:  pool = [Monster.makeGoblin, Monster.makeSkeleton, Monster.makeVoidStalker, Monster.makeDoomGazer]
        case 2:  pool = [Monster.makeOrc, Monster.makeZombie, Monster.makeSoulSucker, Monster.makeCryptSpider, Monster.makeBoneSerpent]
        default: pool = [Monster.makeBloodWraith, Monster.makeDeathScorpion, Monster.makeBoneSerpent, Monster.makeSoulSucker]
        }
        for (i, room) in rooms.dropFirst().dropLast().enumerated() {
            var m = pool[i % pool.count]()
            m.position = GridPosition(row: room.row + room.h / 2, col: room.col + room.w / 2)
            monsters.append(m)
        }

        // Sub-boss before last room
        if rooms.count >= 2 {
            let penultimate = rooms[rooms.count - 2]
            var sub: Monster = difficulty >= 2 ? Monster.makeDeathScorpion() : Monster.makeCryptSpider()
            sub.position = GridPosition(row: penultimate.row + 1, col: penultimate.col + 1)
            monsters.append(sub)
        }

        // Final boss in last room
        if let last = rooms.last {
            var boss = difficulty == 3 ? Monster.makeBigLizard() : Monster.makeTroll()
            boss.position = GridPosition(row: last.row + 1, col: last.col + 1)
            monsters.append(boss)
        }

        updateVisibility()
    }

    func updateVisibility() {
        let radius = 4
        for row in 0..<Dungeon.rows {
            for col in 0..<Dungeon.cols {
                tiles[row][col].visible = false
            }
        }
        let pr = playerPosition.row, pc = playerPosition.col
        for row in max(0, pr - radius)...min(Dungeon.rows - 1, pr + radius) {
            for col in max(0, pc - radius)...min(Dungeon.cols - 1, pc + radius) {
                tiles[row][col].visible = true
                tiles[row][col].explored = true
            }
        }
    }

    func canMove(to pos: GridPosition) -> Bool {
        guard pos.row >= 0 && pos.row < Dungeon.rows,
              pos.col >= 0 && pos.col < Dungeon.cols else { return false }
        return tiles[pos.row][pos.col].type != .wall
    }

    func monsterAt(_ pos: GridPosition) -> Monster? {
        monsters.first { $0.position == pos && $0.isAlive }
    }

    func movePlayer(dr: Int, dc: Int) -> MoveResult {
        let newPos = playerPosition.offset(dr: dr, dc: dc)
        if let monster = monsterAt(newPos) { return .combat(monster) }
        guard canMove(to: newPos) else { return .blocked }

        playerPosition = newPos
        updateVisibility()

        switch tiles[newPos.row][newPos.col].type {
        case .stairs: return .stairs
        case .chest:
            tiles[newPos.row][newPos.col].type = .floor
            let loot = chestLoot()
            return .chest(loot)
        default: return .moved
        }
    }

    private func chestLoot() -> String {
        let loots = [
            "🪙 Found 50 gold pieces!", "⚗️ Found a Potion of Healing (+1d8 HP)!",
            "📜 Found a Scroll of Magic Missile!", "💎 Found a gem worth 100 gold!",
            "🧲 Found a +1 Ring of Protection (AC -1)!", "🍖 Found trail rations. Nice.",
        ]
        return loots.randomElement()!
    }

    func removeMonster(id: UUID) {
        monsters.removeAll { $0.id == id }
    }
}
