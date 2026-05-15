import Foundation
import SwiftUI

// MARK: - Enums

enum CharacterClass: String, CaseIterable, Codable {
    case fighter = "Fighter"
    case mage    = "Mage"
    case cleric  = "Cleric"
    case thief   = "Thief"

    var hitDie: Int {
        switch self { case .fighter: return 10; case .cleric: return 8; case .thief: return 6; case .mage: return 4 }
    }

    func thac0(atLevel level: Int) -> Int {
        let reduction: Int
        switch self {
        case .fighter: reduction = level - 1
        case .cleric:  reduction = (level - 1) * 2 / 3
        case .mage, .thief: reduction = (level - 1) / 2
        }
        return max(-4, 20 - reduction)
    }

    var startingWeapon: Weapon {
        switch self {
        case .fighter: return .longsword
        case .mage:    return .dagger
        case .cleric:  return .mace
        case .thief:   return .shortSword
        }
    }

    var startingAC: Int {
        switch self { case .fighter, .cleric: return 5; case .thief: return 8; case .mage: return 10 }
    }

    var icon: String {
        switch self { case .fighter: return "⚔️"; case .mage: return "🔮"; case .cleric: return "✝️"; case .thief: return "🗡️" }
    }

    var classDescription: String {
        switch self {
        case .fighter: return "Steel and sinew. Best THAC0 progression."
        case .mage:    return "Arcane mastery. Terrible in a fistfight."
        case .cleric:  return "Holy warrior. Can turn undead and heal."
        case .thief:   return "Sneaky backstabber. High risk, high reward."
        }
    }

    var color: Color {
        switch self { case .fighter: return .red; case .mage: return .blue; case .cleric: return .yellow; case .thief: return .green }
    }
}

enum CharacterRace: String, CaseIterable, Codable {
    case human    = "Human"
    case elf      = "Elf"
    case dwarf    = "Dwarf"
    case halfling = "Halfling"

    var icon: String {
        switch self { case .human: return "👤"; case .elf: return "🧝"; case .dwarf: return "⛏️"; case .halfling: return "🌿" }
    }

    var raceDescription: String {
        switch self {
        case .human:    return "+0 to everything. Boring but reliable."
        case .elf:      return "+1 DEX, -1 CON. Sees in the dark."
        case .dwarf:    return "+1 CON, -1 CHA. Hates goblins. Has beard."
        case .halfling: return "+1 DEX, -1 STR. Small but surprisingly brave."
        }
    }

    func applyBonuses(str: inout Int, dex: inout Int, con: inout Int, cha: inout Int) {
        switch self {
        case .human: break
        case .elf:      dex += 1; con -= 1
        case .dwarf:    con += 1; cha -= 1
        case .halfling: dex += 1; str -= 1
        }
    }
}

// MARK: - Weapon

struct Weapon: Codable, Equatable {
    let name: String
    let damageDie: Int
    let damageBonus: Int
    let icon: String

    static let dagger      = Weapon(name: "Dagger",          damageDie: 4,  damageBonus: 0, icon: "🗡️")
    static let shortSword  = Weapon(name: "Short Sword",     damageDie: 6,  damageBonus: 0, icon: "⚔️")
    static let mace        = Weapon(name: "Mace",            damageDie: 6,  damageBonus: 1, icon: "🪃")
    static let longsword   = Weapon(name: "Longsword",       damageDie: 8,  damageBonus: 0, icon: "⚔️")
    static let battleaxe   = Weapon(name: "Battleaxe",       damageDie: 10, damageBonus: 0, icon: "🪓")
    static let twoHander   = Weapon(name: "Two-Handed Sword",damageDie: 12, damageBonus: 0, icon: "⚔️")
}

// MARK: - Character

struct Character: Identifiable, Codable {
    let id: UUID
    var name: String
    var race: CharacterRace
    var characterClass: CharacterClass
    var level: Int = 1

    var strength: Int
    var dexterity: Int
    var constitution: Int
    var intelligence: Int
    var wisdom: Int
    var charisma: Int

    var maxHP: Int
    var currentHP: Int
    var armorClass: Int
    var weapon: Weapon
    var experience: Int = 0

    var thac0: Int { characterClass.thac0(atLevel: level) }
    var isAlive: Bool { currentHP > 0 }
    var strBonus: Int { (strength - 10) / 2 }
    var dexBonus: Int { (dexterity - 10) / 2 }

    // Cumulative XP to reach next level: L1→100, L2→300, L3→600, L4→1000, ...
    var nextLevelXP: Int { level * (level + 1) * 50 }

    init(name: String, race: CharacterRace, characterClass: CharacterClass,
         str: Int, dex: Int, con: Int, int: Int, wis: Int, cha: Int) {
        self.id = UUID()
        self.name = name
        self.race = race
        self.characterClass = characterClass
        self.strength     = str
        self.dexterity    = dex
        self.constitution = con
        self.intelligence = int
        self.wisdom       = wis
        self.charisma     = cha
        let hpRoll = Int.random(in: characterClass.hitDie / 2 ... characterClass.hitDie)
        let conBonus = max(0, (con - 10) / 2)
        self.maxHP = max(1, hpRoll + conBonus)
        self.currentHP = self.maxHP
        self.armorClass = characterClass.startingAC - max(0, (dex - 10) / 2)
        self.weapon = characterClass.startingWeapon
    }

    mutating func gainXP(_ xp: Int) {
        experience += xp
        if experience >= nextLevelXP && level < 100 { levelUp() }
    }

    mutating func levelUp() {
        level += 1
        let gain = Int.random(in: 1...characterClass.hitDie) + max(0, (constitution - 10) / 2)
        maxHP += gain
        currentHP = min(currentHP + gain, maxHP)
    }

    static func rollStat() -> Int {
        (0..<4).map { _ in Int.random(in: 1...6) }.sorted().dropFirst().reduce(0, +)
    }
}

// MARK: - Monster

struct Monster: Identifiable {
    let id: UUID
    var name: String
    var armorClass: Int
    var maxHP: Int
    var currentHP: Int
    var thac0: Int
    var damageDie: Int
    var damageBonus: Int
    var xpValue: Int
    var icon: String
    var flavor: String
    var level: Int
    var position: GridPosition = GridPosition(row: 0, col: 0)
    var isBoss: Bool = false

    var isAlive: Bool { currentHP > 0 }

    var encounterLine: String = ""

    init(name: String, ac: Int, hp: Int, thac0: Int, damageDie: Int,
         damageBonus: Int = 0, xp: Int, icon: String, flavor: String,
         level: Int = 1, boss: Bool = false, encounterLine: String = "") {
        self.id = UUID()
        self.name = name
        self.armorClass = ac
        self.maxHP = hp
        self.currentHP = hp
        self.thac0 = thac0
        self.damageDie = damageDie
        self.damageBonus = damageBonus
        self.xpValue = xp
        self.icon = icon
        self.flavor = flavor
        self.level = level
        self.isBoss = boss
        self.encounterLine = encounterLine
    }

    // AC values use descending THAC0 math: roll ≥ THAC0 − AC to hit.
    // Higher AC = easier to hit (less armor). Unarmored ≈ AC 17-18.
    // Level 1 fighter (THAC0 20) vs goblin (AC 17): needs roll ≥ 3 ✓

    static func makeGoblin() -> Monster {
        Monster(name: "Goblin", ac: 17, hp: Int.random(in: 4...7),
                thac0: 20, damageDie: 6, xp: 25, icon: "👹",
                flavor: "Small. Green. Absolutely rancid.", level: 1,
                encounterLine: "A goblin skitters out from behind a barrel. Smells awful. Confidence completely unwarranted.")
    }
    static func makeSkeleton() -> Monster {
        Monster(name: "Skeleton", ac: 15, hp: Int.random(in: 5...8),
                thac0: 19, damageDie: 6, xp: 35, icon: "💀",
                flavor: "Bones that missed the memo about being dead.", level: 1,
                encounterLine: "Bones creak in the dark. A skeleton assembles itself from the dungeon floor. It points at you. Rude.")
    }
    static func makeOrc() -> Monster {
        Monster(name: "Orc", ac: 13, hp: Int.random(in: 6...12),
                thac0: 18, damageDie: 8, xp: 60, icon: "👾",
                flavor: "Bigger. Uglier. Still rancid.", level: 2,
                encounterLine: "An orc steps into the torchlight. *leans back* Big. Mean. Absolutely going to ruin your evening.")
    }
    static func makeZombie() -> Monster {
        Monster(name: "Zombie", ac: 11, hp: Int.random(in: 8...16),
                thac0: 18, damageDie: 8, xp: 75, icon: "🧟",
                flavor: "Slow. Relentless. Has seen better days.", level: 2,
                encounterLine: "Something shambles toward you. It used to be a person. Now it's your problem.")
    }
    static func makeTroll() -> Monster {
        Monster(name: "Cave Troll", ac: 7, hp: Int.random(in: 28...44),
                thac0: 15, damageDie: 12, damageBonus: 4, xp: 400, icon: "👺",
                flavor: "Regenerates 3 HP/round. Bring fire. Seriously.", level: 5,
                encounterLine: "A cave troll fills the doorway. *slow smile* It regenerates, by the way. I may have forgotten to mention that.")
    }
    static func makeBigLizard() -> Monster {
        Monster(name: "BIG LIZARD", ac: 2, hp: 88,
                thac0: 5, damageDie: 20, damageBonus: 8, xp: 5000, icon: "🐉",
                flavor: "The Big Lizard awakens. Your life choices led you here.",
                level: 20, boss: true,
                encounterLine: "*stands up from behind the screen* This is it. The Big Lizard. This is what it was all building to. I am so proud of this encounter.")
    }

    // MARK: - New monsters

    static func makeSoulSucker() -> Monster {
        Monster(name: "Soul Sucker", ac: 12, hp: Int.random(in: 10...18),
                thac0: 17, damageDie: 8, damageBonus: 1, xp: 120, icon: "🐙",
                flavor: "Three writhing heads. Each one screaming. Different key.", level: 3,
                encounterLine: "Three heads emerge from the slime. Each one screaming. Different key. *drums fingers on the table* Roll for initiative.")
    }
    static func makeDoomGazer() -> Monster {
        Monster(name: "Doom Gazer", ac: 10, hp: Int.random(in: 8...14),
                thac0: 18, damageDie: 6, xp: 100, icon: "👁️",
                flavor: "A floating eye the size of your head. It does not blink.", level: 2,
                encounterLine: "A single eye opens in the darkness ahead. *quiet voice* It's been watching you since the entrance.")
    }
    static func makeVoidStalker() -> Monster {
        Monster(name: "Void Stalker", ac: 14, hp: Int.random(in: 6...10),
                thac0: 19, damageDie: 6, xp: 80, icon: "🦇",
                flavor: "Swarms from the dark. Leathery wings. Completely silent.", level: 2,
                encounterLine: "The torch goes out. You hear wings. *leans forward* Many, many wings.")
    }
    static func makeCryptSpider() -> Monster {
        Monster(name: "Crypt Spider", ac: 13, hp: Int.random(in: 9...16),
                thac0: 18, damageDie: 8, damageBonus: 1, xp: 110, icon: "🕷️",
                flavor: "Webs you can't see until you're already in them.", level: 3,
                encounterLine: "You walk face-first into a web. Something drops from the ceiling behind you. *checks notes* Yeah, it's big.")
    }
    static func makeBoneSerpent() -> Monster {
        Monster(name: "Bone Serpent", ac: 11, hp: Int.random(in: 12...20),
                thac0: 17, damageDie: 8, xp: 130, icon: "🐍",
                flavor: "Undead scales. Rattles like a bag of rocks. Smells worse.", level: 3,
                encounterLine: "Something slithers over your boot. No eyes. *pause* It doesn't need them. It already knows where you are.")
    }
    static func makeBloodWraith() -> Monster {
        Monster(name: "Blood Wraith", ac: 9, hp: Int.random(in: 14...22),
                thac0: 16, damageDie: 10, xp: 200, icon: "👻",
                flavor: "Passes through walls. Feeds on your life force. Unbelievably rude.", level: 4,
                encounterLine: "Temperature drops ten degrees. The figure ahead doesn't cast a shadow. It turns. *very slowly* It smiles.")
    }
    static func makeDeathScorpion() -> Monster {
        Monster(name: "Death Scorpion", ac: 8, hp: Int.random(in: 20...32),
                thac0: 16, damageDie: 10, damageBonus: 2, xp: 250, icon: "🦂",
                flavor: "Claws that shear through plate. The tail is considerably worse.", level: 4,
                encounterLine: "That clicking sound? That's its claws on the stone. *consults notes, nods gravely* The tail is raised. This is fine.")
    }
}

// MARK: - Dungeon

struct GridPosition: Equatable, Hashable {
    var row: Int
    var col: Int
    func offset(dr: Int, dc: Int) -> GridPosition { GridPosition(row: row + dr, col: col + dc) }
}

enum TileType: Int {
    case wall, floor, door, stairs, chest, entrance
}

struct DungeonTile {
    var type: TileType = .wall
    var explored: Bool = false
    var visible: Bool = false
}

enum MoveResult {
    case moved, blocked, combat(Monster), stairs, chest(String)
}

// MARK: - Combat Result

struct CombatResult {
    var attackRoll: Int
    var hit: Bool
    var damage: Int
    var critical: Bool
    var fumble: Bool
    var message: String
}

// MARK: - NPC Party Member

struct PartyMember {
    let name: String
    let role: String
    let icon: String
    let quote: String
    let color: Color
    let thac0: Int
    let damageDie: Int
    let damageBonus: Int
    let maxHP: Int
    let armorClass: Int
    let weaponName: String
    let weaponIcon: String
    let bio: String
}

let npcParty: [PartyMember] = [
    PartyMember(name: "Gretchen", role: "Barbarian", icon: "🪖",
                quote: "I roll for intimidation. Every. Single. Time.",
                color: Color(red: 0.8, green: 0.3, blue: 0.3),
                thac0: 18, damageDie: 8, damageBonus: 2,
                maxHP: 32, armorClass: 7,
                weaponName: "Greataxe", weaponIcon: "🪓",
                bio: "Rage first, questions never. Hails from the Frostpeak Clans."),
    PartyMember(name: "Marcus", role: "Elf Wizard", icon: "🧙",
                quote: "Actually, in the lore, elves don't sleep, they meditate.",
                color: Color(red: 0.3, green: 0.6, blue: 0.9),
                thac0: 20, damageDie: 4, damageBonus: 0,
                maxHP: 14, armorClass: 10,
                weaponName: "Magic Bolt", weaponIcon: "✨",
                bio: "Annoyingly knowledgeable. Has memorized 3 spells. Mentions it often."),
    PartyMember(name: "Biff", role: "Dwarf Fighter", icon: "🪨",
                quote: "...wait whose turn is it? I wasn't paying attention.",
                color: Color(red: 0.6, green: 0.5, blue: 0.3),
                thac0: 19, damageDie: 6, damageBonus: 1,
                maxHP: 28, armorClass: 5,
                weaponName: "War Hammer", weaponIcon: "🔨",
                bio: "Veteran of the Siege of Ironhaven. Mostly remembers the ale."),
]
