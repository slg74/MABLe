import SwiftUI
import Combine

enum GameScreen {
    case title, characterCreation, tableScene, overworld, dungeon, encounter, combat, monsterDefeated, levelUp, victory, gameOver, characterSheet
}

class GameState: ObservableObject {
    @Published var screen: GameScreen = .title
    @Published var player: Character?
    @Published var dungeon: Dungeon?
    @Published var overworldMap: OverworldMap?
    @Published var combatMonster: Monster?
    @Published var combatLog: [String] = []
    @Published var dungeonLevel: Int = 1
    @Published var currentDungeonDifficulty: Int = 1
    @Published var currentDungeonName: String = ""
    @Published var dmQuote: String = "Welcome, brave soul. Try not to die immediately."
    @Published var notification: String = ""
    @Published var showNotification: Bool = false
    @Published var combatReturnScreen: GameScreen = .dungeon
    @Published var charSheetReturn: GameScreen = .tableScene
    @Published var pendingMonster: Monster? = nil
    @Published var encounterMonsterInitiative: Int = 0
    @Published var monsterGoesFirst: Bool = false
    @Published var defeatedMonster: Monster? = nil
    @Published var pendingLevelUp: Bool = false

    private let dmQuotes = [
        "Dude, you rolled a 1. So gnarly.",
        "The goblin headbangs in your direction.",
        "You shred through the dungeon like a Sabbath riff.",
        "The troll regenerates. Of course it does.",
        "Natural 20! The crowd goes wild! There is no crowd.",
        "You step on a pressure plate. I smile. That's bad.",
        "This room smells of orc and broken dreams.",
        "Your torch flickers. The shadows grow. Metal intensifies.",
        "You hear distant chanting... kobold choir practice.",
        "The Big Lizard stirs. You feel a chill.",
        "Roll for sanity. Just kidding. ...Or am I?",
        "The chest is unlocked. Your lucky day. Probably.",
        "Initiative! Do you even know what that means?",
        "A rat watches from the shadows. Judging you.",
        "Somewhere a bard is writing a song about your failures.",
    ]

    // MARK: - Utility

    func flash(_ msg: String) {
        notification = msg
        showNotification = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.showNotification = false
        }
    }

    func randomDMQuote() {
        dmQuote = dmQuotes.randomElement()!
    }

    // MARK: - Game flow

    func startGame(character: Character) {
        player = character
        dungeon = nil
        overworldMap = nil
        combatLog = []
        dungeonLevel = 1
        screen = .tableScene
        dmQuote = "Alright, \(character.name). The dungeon awaits. I've been working on this for weeks. Please don't die in the first room."
    }

    func enterOverworld() {
        overworldMap = OverworldMap()
        screen = .overworld
        dmQuote = "You step outside into the overworld. Thornwall village is nearby — head west. Explore. The dungeon entrances will make themselves known."
        AmbientAudio.shared.play(.overworld)
    }

    func enterDungeonAt(difficulty: Int, name: String) {
        currentDungeonDifficulty = difficulty
        currentDungeonName = name
        dungeon = Dungeon(difficulty: difficulty)
        dungeonLevel = 1
        combatLog = []
        screen = .dungeon
        dmQuote = "Entering \(name). Difficulty \(difficulty). \(difficulty == 3 ? "It was nice knowing you." : "You've got this. Probably.")"
        AmbientAudio.shared.play(.dungeon)
    }

    func returnToOverworld() {
        screen = .overworld
        randomDMQuote()
        AmbientAudio.shared.play(.overworld)
    }

    // MARK: - Character Sheet

    func openCharacterSheet() {
        charSheetReturn = screen
        screen = .characterSheet
    }

    // MARK: - Combat – player attacks (THAC0)

    func initiateCombat(with monster: Monster, returnTo: GameScreen = .dungeon) {
        combatReturnScreen = returnTo
        pendingMonster = monster
        encounterMonsterInitiative = Int.random(in: 1...20)
        monsterGoesFirst = false
        screen = .encounter
        AmbientAudio.shared.play(.combat)
    }

    func beginCombat(monsterFirst: Bool) {
        guard let monster = pendingMonster else { return }
        monsterGoesFirst = monsterFirst
        combatMonster = monster
        combatLog = ["⚔️ \(monster.name) lunges from the darkness!", "📖 \(monster.flavor)"]
        pendingMonster = nil
        screen = .combat
        randomDMQuote()
    }

    // MARK: - Monster death (shared by all attack paths)

    func handleMonsterDeath(_ monster: Monster) {
        guard var updatedCh = player else { return }
        let partySize = npcParty.count + 1          // player + 3 NPCs
        let xpEach = max(1, monster.xpValue / partySize)
        let prevLevel = updatedCh.level
        updatedCh.gainXP(xpEach)
        let didLevel = updatedCh.level > prevLevel
        player = updatedCh
        dungeon?.removeMonster(id: monster.id)
        combatLog.append("🎉 \(monster.name) slain! +\(xpEach) XP each")
        combatMonster = nil
        defeatedMonster = monster
        pendingLevelUp = didLevel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.screen = .monsterDefeated
            self?.randomDMQuote()
        }
    }

    func playerAttack() -> CombatResult {
        guard var ch = player, var monster = combatMonster else {
            return CombatResult(attackRoll: 0, hit: false, damage: 0, critical: false, fumble: false, message: "?")
        }

        let roll    = Int.random(in: 1...20)
        let needed  = ch.thac0 - monster.armorClass
        let critical = roll == 20
        let fumble   = roll == 1

        var damage = 0
        var msg = ""

        if fumble {
            damage = Int.random(in: 1...4)
            ch.currentHP -= damage
            msg = "💀 FUMBLE! You hit yourself for \(damage). Embarrassing."
            player = ch
        } else if critical {
            damage = max(1, Int.random(in: 1...ch.weapon.damageDie) * 2 + ch.strBonus + ch.weapon.damageBonus)
            monster.currentHP -= damage
            msg = "⚡ CRITICAL HIT! \(damage) damage! FACE MELT!"
        } else if roll >= max(needed, 2) {
            damage = max(1, Int.random(in: 1...ch.weapon.damageDie) + ch.strBonus + ch.weapon.damageBonus)
            monster.currentHP -= damage
            msg = "✅ Hit! \(ch.weapon.icon) \(damage) dmg (rolled \(roll), needed \(needed))."
        } else {
            msg = "❌ Miss. (Rolled \(roll), needed \(needed) vs AC \(monster.armorClass))"
        }

        combatLog.append(msg)

        if !monster.isAlive {
            handleMonsterDeath(monster)
        } else {
            combatMonster = monster
        }

        return CombatResult(attackRoll: roll,
                            hit: !fumble && (critical || roll >= max(needed, 2)),
                            damage: damage, critical: critical, fumble: fumble, message: msg)
    }

    // MARK: - Two-phase combat

    struct HitResult {
        var roll: Int; var hit: Bool; var critical: Bool; var fumble: Bool; var message: String
    }

    func rollToHit() -> HitResult {
        guard var ch = player, let monster = combatMonster else {
            return HitResult(roll: 1, hit: false, critical: false, fumble: true, message: "No target.")
        }
        let roll    = Int.random(in: 1...20)
        let needed  = max(ch.thac0 - monster.armorClass, 2)
        let critical = roll == 20
        let fumble   = roll == 1
        var hit = false
        var msg = ""

        if fumble {
            let dmg = Int.random(in: 1...4)
            ch.currentHP -= dmg
            player = ch
            msg = "💀 FUMBLE! You hit yourself for \(dmg). Embarrassing."
            if !ch.isAlive {
                combatLog.append(msg)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.screen = .gameOver }
            }
        } else if critical {
            hit = true
            msg = "⚡️ CRITICAL! (Rolled 20) Roll for double damage!"
        } else if roll >= needed {
            hit = true
            msg = "✅ Hit! Rolled \(roll) vs AC \(monster.armorClass) — roll damage!"
        } else {
            msg = "❌ Miss. (Rolled \(roll), needed ≥\(needed) vs AC \(monster.armorClass))"
        }
        combatLog.append(msg)
        return HitResult(roll: roll, hit: hit, critical: critical, fumble: fumble, message: msg)
    }

    func rollDamage(critical: Bool) -> CombatResult {
        guard let ch = player, var monster = combatMonster else {
            return CombatResult(attackRoll: 1, hit: true, damage: 0, critical: critical, fumble: false, message: "?")
        }
        let dieRoll = Int.random(in: 1...ch.weapon.damageDie)
        let dmg: Int
        let msg: String
        if critical {
            dmg = max(1, dieRoll * 2 + ch.strBonus + ch.weapon.damageBonus + 5)
            msg = "⚡️ CRITICAL! \(ch.weapon.icon) \(ch.weapon.name): \(dmg) dmg (2×\(dieRoll)+5)!"
        } else {
            dmg = max(1, dieRoll + ch.strBonus + ch.weapon.damageBonus)
            msg = "💥 \(ch.weapon.icon) \(ch.weapon.name): \(dmg) dmg (rolled \(dieRoll))"
        }
        monster.currentHP -= dmg
        combatLog.append(msg)

        if !monster.isAlive {
            handleMonsterDeath(monster)
        } else {
            combatMonster = monster
        }
        return CombatResult(attackRoll: dieRoll, hit: true, damage: dmg, critical: critical, fumble: false, message: msg)
    }

    // MARK: - Combat – NPC party auto-attacks

    struct PartyAttackResult {
        var member: PartyMember; var roll: Int; var hit: Bool; var damage: Int; var damageRoll: Int
    }

    func partySingleAttack(member: PartyMember) -> PartyAttackResult {
        guard var monster = combatMonster else {
            return PartyAttackResult(member: member, roll: 0, hit: false, damage: 0, damageRoll: 0)
        }
        let roll    = Int.random(in: 1...20)
        let needed  = max(member.thac0 - monster.armorClass, 2)
        let hit     = roll == 20 || roll >= needed
        var dmg     = 0
        var dieRoll = 0
        if hit {
            dieRoll = Int.random(in: 1...member.damageDie)
            dmg = max(1, dieRoll + member.damageBonus)
            monster.currentHP -= dmg
            combatLog.append("\(member.icon) \(member.name): \(member.weaponIcon) \(dmg) dmg (d20:\(roll) / d\(member.damageDie):\(dieRoll))")
        } else {
            combatLog.append("\(member.icon) \(member.name): miss (d20:\(roll), need ≥\(needed))")
        }

        if !monster.isAlive {
            handleMonsterDeath(monster)
        } else {
            combatMonster = monster
        }
        return PartyAttackResult(member: member, roll: roll, hit: hit, damage: dmg, damageRoll: dieRoll)
    }

    // MARK: - Combat – monster attacks

    func monsterAttack() -> CombatResult {
        guard var ch = player, let monster = combatMonster else {
            return CombatResult(attackRoll: 0, hit: false, damage: 0, critical: false, fumble: false, message: "?")
        }

        let roll   = Int.random(in: 1...20)
        let needed = monster.thac0 - ch.armorClass
        let hit    = roll == 20 || roll >= max(needed, 2)

        var damage = 0
        var msg = ""

        if hit {
            damage = max(1, Int.random(in: 1...monster.damageDie) + monster.damageBonus)
            ch.currentHP -= damage
            msg = "🔴 \(monster.name) hits for \(damage)! (rolled \(roll))"
        } else {
            msg = "🛡 \(monster.name) misses. (Rolled \(roll), needed \(needed))"
        }

        player = ch
        combatLog.append(msg)

        if !ch.isAlive {
            combatLog.append("💀 You have been slain by \(monster.name)!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.screen = .gameOver
            }
        }

        return CombatResult(attackRoll: roll, hit: hit, damage: damage, critical: false, fumble: false, message: msg)
    }

    // MARK: - Dungeon flow

    func descend() {
        dungeonLevel += 1
        dungeon = Dungeon(difficulty: currentDungeonDifficulty)
        screen = .dungeon
        flash("⬇️ Level \(dungeonLevel) of \(currentDungeonName)!")
        randomDMQuote()
    }

    func checkDungeonCleared() {
        guard let d = dungeon else { screen = .dungeon; return }
        let bossAlive = d.monsters.contains { $0.isBoss && $0.isAlive }
        let hadBoss   = d.monsters.contains { $0.isBoss }

        if hadBoss && !bossAlive {
            if currentDungeonDifficulty == 3 {
                screen = .victory
            } else {
                let bonus = currentDungeonDifficulty * 500
                flash("🏆 \(currentDungeonName) cleared! +\(bonus) XP")
                if var p = player { p.gainXP(bonus); player = p }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.returnToOverworld()
                }
            }
        } else {
            screen = .dungeon
        }
    }

    // MARK: - Save / Load

    private let saveKey = "MazesAndBigLizards_SavedGame"

    var hasSavedGame: Bool {
        UserDefaults.standard.data(forKey: saveKey) != nil
    }

    func saveGame() {
        guard let p = player else { return }
        let save = SavedGame(
            player: p,
            inDungeon: dungeon != nil,
            overworldRow: overworldMap?.playerPos.row ?? 18,
            overworldCol: overworldMap?.playerPos.col ?? 10,
            dungeonLevel: dungeonLevel,
            dungeonDifficulty: currentDungeonDifficulty,
            dungeonName: currentDungeonName,
            dmQuote: dmQuote
        )
        if let data = try? JSONEncoder().encode(save) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    func loadGame() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let save = try? JSONDecoder().decode(SavedGame.self, from: data) else { return }
        player = save.player
        dungeonLevel = save.dungeonLevel
        currentDungeonDifficulty = save.dungeonDifficulty
        currentDungeonName = save.dungeonName
        dmQuote = save.dmQuote
        combatLog = []
        combatMonster = nil
        if save.inDungeon && !save.dungeonName.isEmpty {
            dungeon = Dungeon(difficulty: save.dungeonDifficulty)
            overworldMap = nil
            screen = .dungeon
            AmbientAudio.shared.play(.dungeon)
            dmQuote = "Back in \(save.dungeonName), floor \(save.dungeonLevel). Right where you left off. More or less."
        } else {
            dungeon = nil
            overworldMap = OverworldMap(startPos: GridPosition(row: save.overworldRow, col: save.overworldCol))
            screen = .overworld
            AmbientAudio.shared.play(.overworld)
            dmQuote = "Welcome back, \(save.player.name). The overworld didn't miss you. I did."
        }
    }

    func deleteSave() {
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    func exitAndSave() {
        saveGame()
        combatMonster = nil
        dungeon = nil
        screen = .title
        AmbientAudio.shared.stop()
    }

    func reset() {
        player        = nil
        dungeon       = nil
        overworldMap  = nil
        combatMonster = nil
        combatLog     = []
        dungeonLevel  = 1
        screen        = .title
    }
}
