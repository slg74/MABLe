import SwiftUI

private enum CombatPhase { case rollToHit, rollDamage }

struct CombatView: View {
    @EnvironmentObject var gs: GameState
    @State private var phase: CombatPhase = .rollToHit
    @State private var pendingCritical: Bool = false
    @State private var displayedValue: Int = 20
    @State private var isRolling: Bool = false
    @State private var hitResult: GameState.HitResult? = nil
    @State private var damageResult: CombatResult? = nil
    @State private var showResult: Bool = false
    @State private var pulseMonster: Bool = false
    @State private var shakePlayer: Bool = false
    @State private var partyResults: [GameState.PartyAttackResult] = []

    var weaponDie: Int { gs.player?.weapon.damageDie ?? 6 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.03, blue: 0.03),
                                    Color(red: 0.06, green: 0.02, blue: 0.06),
                                    Color(red: 0.12, green: 0.03, blue: 0.03)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                CombatHeader()

                if !gs.dmQuote.isEmpty {
                    Text("🤘 \u{201C}\(gs.dmQuote)\u{201D}")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                        .italic()
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 4)

                if let monster = gs.combatMonster {
                    MonsterDisplay(monster: monster, pulse: pulseMonster)
                        .padding(.horizontal, 24)
                }

                if let p = gs.player, let m = gs.combatMonster {
                    CombatThac0Strip(player: p, monster: m)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                }

                Spacer(minLength: 4)

                // Phase label
                HStack(spacing: 10) {
                    phaseChip(label: "1  TO HIT", active: phase == .rollToHit)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.3))
                    phaseChip(label: "2  DAMAGE", active: phase == .rollDamage)
                }
                .padding(.bottom, 4)

                // Dice + result
                let sides = phase == .rollToHit ? 20 : weaponDie
                DiceDisplay(value: displayedValue, sides: sides, isRolling: isRolling)
                    .padding(.vertical, 2)

                if showResult {
                    if phase == .rollToHit, let r = hitResult {
                        ResultBanner(icon: r.critical ? "⚡️" : r.hit ? "✅" : r.fumble ? "💀" : "❌",
                                     message: r.message, bg: r.hit ? Color(red:0,green:0.2,blue:0) : Color(white:0.08))
                            .padding(.horizontal, 24)
                            .transition(.scale.combined(with: .opacity))
                    } else if phase == .rollDamage, let r = damageResult {
                        ResultBanner(icon: r.critical ? "⚡️" : "💥",
                                     message: r.message, damage: r.damage,
                                     bg: r.critical ? Color(red:0.5,green:0.3,blue:0) : Color(red:0.2,green:0.05,blue:0))
                            .padding(.horizontal, 24)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Spacer(minLength: 4)

                // Player HP
                if let p = gs.player {
                    PlayerHUD(player: p)
                        .padding(.horizontal, 16)
                        .offset(x: shakePlayer ? -6 : 0)
                        .animation(.easeInOut(duration: 0.05).repeatCount(6), value: shakePlayer)
                }

                // Party attack results
                if !partyResults.isEmpty {
                    PartyAttacksStrip(results: partyResults)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 4)

                // Armed weapon + attack buttons
                VStack(spacing: 8) {
                    if let p = gs.player {
                        ArmedWeaponRow(weapon: p.weapon)
                    }

                    if phase == .rollToHit {
                        Button("⚔️   ROLL TO HIT   (d20)") { doRollToHit() }
                            .buttonStyle(MetalButtonStyle(color: Color(red: 0.55, green: 0.05, blue: 0.05)))
                            .disabled(isRolling)
                    } else {
                        Button("💥   ROLL DAMAGE   (1d\(weaponDie))") { doRollDamage() }
                            .buttonStyle(MetalButtonStyle(color: Color(red: 0.65, green: 0.25, blue: 0.0)))
                            .disabled(isRolling)
                    }

                    Button("🏃 FLEE (1-in-3 chance)") {
                        if Int.random(in: 1...3) == 1 {
                            gs.flash("💨 You escaped!")
                            gs.screen = gs.combatReturnScreen == .overworld ? .overworld : .dungeon
                            gs.randomDMQuote()
                        } else {
                            gs.flash("😱 Couldn't flee! Monster attacks!")
                            monsterAttack()
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .disabled(isRolling)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                CombatLogView(entries: gs.combatLog)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .onAppear {
            displayedValue = 20
            phase = .rollToHit
            if gs.monsterGoesFirst {
                gs.monsterGoesFirst = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { monsterAttack() }
            }
        }
    }

    @ViewBuilder
    private func phaseChip(label: String, active: Bool) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(active ? .white : Color(white: 0.3))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(active ? Color.red.opacity(0.35) : Color(white: 0.08))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(active ? Color.red.opacity(0.6) : Color(white: 0.18), lineWidth: 1))
    }

    // MARK: - Phase 1: roll to hit

    private func doRollToHit() {
        guard !isRolling else { return }
        isRolling = true
        showResult = false
        displayedValue = Int.random(in: 1...20)

        let delays: [Double] = [0.04,0.04,0.04,0.04,0.05,0.05,0.06,0.08,0.10,0.13,0.17,0.22,0.28,0.36]
        var tick = 0
        func step() {
            guard tick < delays.count else {
                let result = gs.rollToHit()
                hitResult = result
                damageResult = nil
                displayedValue = result.roll
                isRolling = false
                withAnimation(.spring()) { showResult = true }

                if result.fumble {
                    shakePlayer = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakePlayer = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { monsterAttack() }
                } else if result.hit {
                    pendingCritical = result.critical
                    withAnimation(.easeInOut(duration: 0.15).repeatCount(3)) { pulseMonster = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { pulseMonster = false }
                    // advance to damage phase
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            phase = .rollDamage
                            displayedValue = weaponDie
                            showResult = false
                        }
                    }
                } else {
                    // miss — monster attacks
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { monsterAttack() }
                }
                return
            }
            displayedValue = Int.random(in: 1...20)
            let d = delays[tick]; tick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + d) { step() }
        }
        step()
    }

    // MARK: - Phase 2: roll damage

    private func doRollDamage() {
        guard !isRolling else { return }
        isRolling = true
        showResult = false
        displayedValue = Int.random(in: 1...weaponDie)

        let delays: [Double] = [0.05,0.05,0.05,0.06,0.07,0.08,0.10,0.13,0.17,0.22,0.28,0.35]
        var tick = 0
        func step() {
            guard tick < delays.count else {
                let result = gs.rollDamage(critical: pendingCritical)
                damageResult = result
                hitResult = nil
                displayedValue = result.attackRoll
                isRolling = false
                withAnimation(.spring()) { showResult = true }

                withAnimation(.easeInOut(duration: 0.15).repeatCount(4)) { pulseMonster = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pulseMonster = false }

                if gs.screen == .combat {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        monsterAttack()
                        phase = .rollToHit
                        displayedValue = 20
                        showResult = false
                    }
                }
                return
            }
            displayedValue = Int.random(in: 1...weaponDie)
            let d = delays[tick]; tick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + d) { step() }
        }
        step()
    }

    private func monsterAttack() {
        let result = gs.monsterAttack()
        if result.hit {
            shakePlayer = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakePlayer = false }
        }
        withAnimation { partyResults = [] }
        for (i, member) in npcParty.shuffled().enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.85) {
                guard gs.screen == .combat, gs.combatMonster != nil else { return }
                let r = gs.partySingleAttack(member: member)
                withAnimation(.spring(response: 0.3)) { partyResults.append(r) }
                if r.hit {
                    withAnimation(.easeInOut(duration: 0.1).repeatCount(3)) { pulseMonster = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pulseMonster = false }
                }
            }
        }
    }
}

// MARK: - Combat Header

struct CombatHeader: View {
    @EnvironmentObject var gs: GameState

    var body: some View {
        HStack {
            Text("⚔️ COMBAT")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.red)
            Spacer()
            if let m = gs.combatMonster {
                let pIcon = gs.player?.characterClass.icon ?? "🧑"
                Text("\(pIcon) vs \(m.icon)")
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.2, green: 0.02, blue: 0.02))
    }
}

// MARK: - THAC0 Strip

struct CombatThac0Strip: View {
    let player: Character
    let monster: Monster

    var playerNeeds: Int { max(player.thac0 - monster.armorClass, 2) }
    var monsterNeeds: Int { max(monster.thac0 - player.armorClass, 2) }

    var playerNeedColor: Color { playerNeeds <= 8 ? .green : playerNeeds <= 14 ? .yellow : .red }
    var monsterNeedColor: Color { monsterNeeds >= 15 ? .green : monsterNeeds >= 9 ? .yellow : .red }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("YOUR ATTACK")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.35)).tracking(1)
                HStack(spacing: 3) {
                    Text("THAC0 \(player.thac0)").font(.system(size: 9, design: .monospaced)).foregroundColor(.cyan)
                    Text("− AC \(monster.armorClass)").font(.system(size: 9, design: .monospaced)).foregroundColor(.orange)
                }
                Text("NEED ≥ \(playerNeeds)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(playerNeedColor)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 5)
            .background(Color.cyan.opacity(0.05))

            Rectangle().fill(Color(white: 0.18)).frame(width: 1).padding(.vertical, 4)

            VStack(spacing: 2) {
                Text("ENEMY ATTACK")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.35)).tracking(1)
                HStack(spacing: 3) {
                    Text("THAC0 \(monster.thac0)").font(.system(size: 9, design: .monospaced)).foregroundColor(.orange)
                    Text("− AC \(player.armorClass)").font(.system(size: 9, design: .monospaced)).foregroundColor(.cyan)
                }
                Text("NEEDS ≥ \(monsterNeeds)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(monsterNeedColor)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 5)
            .background(Color.red.opacity(0.05))
        }
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.18), lineWidth: 1))
    }
}

// MARK: - Armed weapon row

struct ArmedWeaponRow: View {
    let weapon: Weapon

    var body: some View {
        HStack(spacing: 10) {
            Text(weapon.icon).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 1) {
                Text(weapon.name)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                let dieStr = weapon.damageBonus > 0 ? "1d\(weapon.damageDie)+\(weapon.damageBonus)" : "1d\(weapon.damageDie)"
                Text(dieStr)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.orange)
            }
            Spacer()
            Text("ARMED")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.green.opacity(0.5), lineWidth: 1))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(white: 0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.18), lineWidth: 1))
    }
}

// MARK: - Monster Display

struct MonsterDisplay: View {
    let monster: Monster
    let pulse: Bool

    var hpFraction: Double { Double(monster.currentHP) / Double(monster.maxHP) }

    var body: some View {
        VStack(spacing: 5) {
            Text(monster.icon)
                .font(.system(size: monster.isBoss ? 58 : 46))
                .scaleEffect(pulse ? 1.12 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: pulse)
                .shadow(color: monster.isBoss ? .red.opacity(0.8) : .orange.opacity(0.5),
                        radius: monster.isBoss ? 20 : 10)
            HStack(spacing: 6) {
                Text(monster.name)
                    .font(.system(size: monster.isBoss ? 17 : 14, weight: .black, design: .monospaced))
                    .foregroundColor(monster.isBoss ? .red : .orange)
                Text("LVL \(monster.level)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.12)))
            }
            Text(monster.flavor)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(white: 0.4)).italic().multilineTextAlignment(.center)
            VStack(spacing: 2) {
                HStack {
                    Text("HP: \(monster.currentHP)/\(monster.maxHP)")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(Color(white: 0.5))
                    Spacer()
                    Text("AC \(monster.armorClass)  •  THAC0 \(monster.thac0)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(Color(white: 0.45))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.15))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(hpFraction > 0.5 ? Color.orange : (hpFraction > 0.25 ? .yellow : .red))
                            .frame(width: geo.size.width * hpFraction)
                            .animation(.easeInOut(duration: 0.3), value: monster.currentHP)
                    }
                }.frame(height: 7)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.07))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(monster.isBoss ? Color.red.opacity(0.5) : Color.orange.opacity(0.3),
                            lineWidth: monster.isBoss ? 2 : 1))
        )
    }
}

// MARK: - Die shape canvas (d4/d6/d8/d10/d12/d20)

struct CombatDieShape: View {
    let sides: Int
    let value: Int
    let isRolling: Bool
    let faceColor: Color

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w / 2, cy = h / 2
            let m: CGFloat = 3

            var outer = Path()
            var facets = Path()
            var numberCenter = CGPoint(x: cx, y: cy)
            var innerFill: (Path, Color)? = nil

            switch sides {

            case 4:     // Equilateral triangle, no inner lines
                let top  = CGPoint(x: cx, y: m)
                let botL = CGPoint(x: m,   y: h - m)
                let botR = CGPoint(x: w-m, y: h - m)
                outer.move(to: top); outer.addLine(to: botR); outer.addLine(to: botL)
                outer.closeSubpath()
                numberCenter = CGPoint(x: cx, y: h * 0.63)

            case 6:     // Square
                outer.move(to: CGPoint(x: m,   y: m))
                outer.addLine(to: CGPoint(x: w-m, y: m))
                outer.addLine(to: CGPoint(x: w-m, y: h-m))
                outer.addLine(to: CGPoint(x: m,   y: h-m))
                outer.closeSubpath()
                // diagonal highlight lines
                facets.move(to: CGPoint(x: m, y: m)); facets.addLine(to: CGPoint(x: w-m, y: h-m))
                facets.move(to: CGPoint(x: w-m, y: m)); facets.addLine(to: CGPoint(x: m, y: h-m))
                // inner fill for lit quadrant
                var litQ = Path()
                litQ.move(to: CGPoint(x: cx, y: m)); litQ.addLine(to: CGPoint(x: w-m, y: cy))
                litQ.addLine(to: CGPoint(x: cx, y: cy)); litQ.closeSubpath()
                innerFill = (litQ, faceColor.opacity(isRolling ? 0.08 : 0.18))

            case 8:     // Diamond
                outer.move(to: CGPoint(x: cx,   y: m))
                outer.addLine(to: CGPoint(x: w-m, y: cy))
                outer.addLine(to: CGPoint(x: cx,   y: h-m))
                outer.addLine(to: CGPoint(x: m,    y: cy))
                outer.closeSubpath()
                facets.move(to: CGPoint(x: cx, y: m)); facets.addLine(to: CGPoint(x: cx, y: h-m))
                facets.move(to: CGPoint(x: m, y: cy)); facets.addLine(to: CGPoint(x: w-m, y: cy))
                // upper-right lit triangle
                var litD = Path()
                litD.move(to: CGPoint(x: cx, y: m)); litD.addLine(to: CGPoint(x: w-m, y: cy))
                litD.addLine(to: CGPoint(x: cx, y: cy)); litD.closeSubpath()
                innerFill = (litD, faceColor.opacity(isRolling ? 0.08 : 0.18))

            case 10:    // Kite (narrow top, wider middle, pointed bottom)
                let topPt  = CGPoint(x: cx,   y: m)
                let rightPt = CGPoint(x: w-m, y: cy - h * 0.08)
                let botPt  = CGPoint(x: cx,   y: h-m)
                let leftPt = CGPoint(x: m,    y: cy - h * 0.08)
                outer.move(to: topPt); outer.addLine(to: rightPt)
                outer.addLine(to: botPt); outer.addLine(to: leftPt); outer.closeSubpath()
                // center equator line
                let midY = (topPt.y + rightPt.y) / 2 + (botPt.y - rightPt.y) * 0.35
                facets.move(to: CGPoint(x: leftPt.x + 2, y: midY))
                facets.addLine(to: CGPoint(x: rightPt.x - 2, y: midY))
                facets.move(to: CGPoint(x: cx, y: topPt.y + 2))
                facets.addLine(to: CGPoint(x: cx, y: botPt.y - 2))

            case 12:    // Pentagon
                let r = min(cx, cy) - m
                for i in 0..<5 {
                    let a = CGFloat(i) * .pi * 2 / 5 - .pi / 2
                    let pt = CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
                    if i == 0 { outer.move(to: pt) } else { outer.addLine(to: pt) }
                }
                outer.closeSubpath()
                // inner pentagon ring
                let r2 = r * 0.52
                for i in 0..<5 {
                    let a = CGFloat(i) * .pi * 2 / 5 - .pi / 2
                    let pt = CGPoint(x: cx + r2 * cos(a), y: cy + r2 * sin(a))
                    if i == 0 { facets.move(to: pt) } else { facets.addLine(to: pt) }
                    let outerPt = CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
                    let innerPt = CGPoint(x: cx + r2 * cos(a), y: cy + r2 * sin(a))
                    facets.move(to: outerPt); facets.addLine(to: innerPt)
                }
                facets.closeSubpath()

            default:    // D20: triangle with inner midpoint sub-triangle
                let top  = CGPoint(x: cx, y: m)
                let botL = CGPoint(x: m,   y: h - m)
                let botR = CGPoint(x: w-m, y: h - m)
                outer.move(to: top); outer.addLine(to: botR); outer.addLine(to: botL)
                outer.closeSubpath()
                let mTL = CGPoint(x: (top.x + botL.x)/2, y: (top.y + botL.y)/2)
                let mTR = CGPoint(x: (top.x + botR.x)/2, y: (top.y + botR.y)/2)
                let mB  = CGPoint(x: (botL.x + botR.x)/2, y: (botL.y + botR.y)/2)
                facets.move(to: mTL); facets.addLine(to: mTR)
                facets.move(to: mTR); facets.addLine(to: mB)
                facets.move(to: mB);  facets.addLine(to: mTL)
                var litInner = Path()
                litInner.move(to: mTL); litInner.addLine(to: mTR); litInner.addLine(to: mB)
                litInner.closeSubpath()
                innerFill = (litInner, faceColor.opacity(isRolling ? 0.10 : 0.20))
                numberCenter = CGPoint(x: (mTL.x+mTR.x+mB.x)/3, y: (mTL.y+mTR.y+mB.y)/3)
            }

            // Fill base
            ctx.fill(outer, with: .color(Color(white: 0.08)))
            if let (path, color) = innerFill { ctx.fill(path, with: .color(color)) }
            ctx.stroke(outer, with: .color(faceColor), lineWidth: 2.0)
            ctx.stroke(facets, with: .color(faceColor.opacity(0.38)), lineWidth: 0.9)

            ctx.draw(
                Text("\(value)")
                    .font(.system(size: h * 0.28, weight: .black, design: .monospaced))
                    .foregroundColor(isRolling ? faceColor.opacity(0.48) : faceColor),
                at: numberCenter, anchor: .center
            )
        }
    }
}

// MARK: - Dice Display

struct DiceDisplay: View {
    let value: Int
    let sides: Int
    let isRolling: Bool

    @State private var rotation: Double = 0
    @State private var bounceScale: CGFloat = 1.0

    var resultColor: Color {
        if sides == 20 {
            if value == 20 { return .yellow }
            if value == 1  { return .red }
            if value >= 15 { return .green }
            if value >= 10 { return .white }
            return Color(white: 0.55)
        }
        // damage die — scale by fraction of max
        let frac = Double(value) / Double(sides)
        if frac >= 0.85 { return .yellow }
        if frac >= 0.5  { return .green }
        if frac >= 0.25 { return .white }
        return Color(white: 0.5)
    }

    var dieLabel: String {
        if sides == 20 {
            return value == 20 ? "NATURAL 20 🔥" : value == 1 ? "FUMBLE 💀" : isRolling ? "ROLLING d20..." : "d20 ROLL"
        }
        return isRolling ? "ROLLING d\(sides)..." : "d\(sides) DAMAGE"
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if !isRolling {
                    Circle().fill(resultColor.opacity(0.10)).frame(width: 100, height: 100)
                    Circle().strokeBorder(resultColor.opacity(0.28), lineWidth: 1.5).frame(width: 96, height: 96)
                }
                CombatDieShape(sides: sides, value: value, isRolling: isRolling, faceColor: resultColor)
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(bounceScale)
                    .shadow(color: resultColor.opacity(isRolling ? 0.25 : 0.75),
                            radius: isRolling ? 4 : 14)
            }
            .frame(width: 100, height: 100)
            .onChange(of: value) { _ in
                if isRolling {
                    withAnimation(.linear(duration: 0.06)) { rotation += Double.random(in: 55...115) }
                }
            }
            .onChange(of: isRolling) { rolling in
                if !rolling {
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.30)) { bounceScale = 1.38 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.55)) { bounceScale = 1.0 }
                    }
                }
            }
            // Reset rotation/scale when switching die type
            .onChange(of: sides) { _ in
                withAnimation(.none) { rotation = 0; bounceScale = 1.0 }
            }

            Text("\(value)")
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .foregroundColor(resultColor)
                .opacity(isRolling ? 0.45 : 1.0)
                .shadow(color: resultColor.opacity(isRolling ? 0 : 0.85), radius: isRolling ? 0 : 10)
                .animation(.easeInOut(duration: 0.18), value: isRolling)

            Text(dieLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(value == 20 && sides == 20 ? .yellow :
                                 value == 1  && sides == 20 ? .red   : Color(white: 0.4))
                .tracking(1)
        }
    }
}

// MARK: - Result Banner

struct ResultBanner: View {
    let icon: String
    let message: String
    var damage: Int = 0
    let bg: Color

    var body: some View {
        HStack {
            Text(icon).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
                if damage > 0 {
                    Text("\(damage) damage")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.red)
                }
            }
            Spacer()
        }
        .padding(10).background(bg).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.25), lineWidth: 1))
    }
}

// MARK: - Party Attacks Strip

struct PartyAttacksStrip: View {
    let results: [GameState.PartyAttackResult]

    var body: some View {
        HStack(spacing: 6) {
            Text("PARTY")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.35))
                .tracking(1)

            Rectangle().fill(Color(white: 0.2)).frame(width: 1, height: 16)

            ForEach(Array(results.enumerated()), id: \.offset) { i, r in
                if i > 0 {
                    Rectangle().fill(Color(white: 0.15)).frame(width: 1, height: 14)
                }
                HStack(spacing: 3) {
                    Text(r.member.icon).font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.hit ? "+\(r.damage)" : "MISS")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(r.hit ? .green : Color(white: 0.28))
                        HStack(spacing: 3) {
                            Text("d20:\(r.roll)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(r.roll == 20 ? .yellow : Color(white: 0.35))
                            if r.hit {
                                Text("d\(r.member.damageDie):\(r.damageRoll)")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.07))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(white: 0.15), lineWidth: 1))
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}

// MARK: - Combat Log

struct CombatLogView: View {
    let entries: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { i, entry in
                        Text(entry)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(logColor(entry))
                            .id(i)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            .frame(height: 62)
            .background(Color(white: 0.05)).cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(white: 0.15), lineWidth: 1))
            .onChange(of: entries.count) { _ in
                if let last = entries.indices.last { withAnimation { proxy.scrollTo(last) } }
            }
        }
    }

    func logColor(_ s: String) -> Color {
        if s.contains("CRITICAL") || s.contains("⚡️") { return .yellow }
        if s.contains("FUMBLE")   || s.contains("💀")  { return .red }
        if s.contains("✅")                             { return .green }
        if s.contains("🔴")                             { return Color(red: 1, green: 0.4, blue: 0.4) }
        if s.contains("🎉")                             { return .cyan }
        return Color(white: 0.55)
    }
}
