import SwiftUI

struct TableSceneView: View {
    @EnvironmentObject var gs: GameState
    @State private var flickerA: Bool = false
    @State private var flickerB: Bool = false
    @State private var dmArm: Bool = false
    @State private var quoteIndex: Int = 0
    @State private var showPartyQuote: Bool = false
    @State private var partyQuoteText: String = ""

    var body: some View {
        ZStack {
            // Basement atmosphere
            LinearGradient(colors: [Color(red: 0.06, green: 0.04, blue: 0.08),
                                    Color(red: 0.12, green: 0.08, blue: 0.10),
                                    Color(red: 0.04, green: 0.03, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Ceiling light glow
            RadialGradient(colors: [Color(red: 1.0, green: 0.9, blue: 0.6).opacity(0.15), .clear],
                           center: .top, startRadius: 0, endRadius: 300)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("🤘 MAZES & BIG LIZARDS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                    Spacer()
                    if let p = gs.player {
                        Text("\(p.characterClass.icon) \(p.name)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(p.characterClass.color.opacity(0.8))
                    }
                    MusicToggleButton()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // ── DM AREA ──────────────────────────────────────────────
                VStack(spacing: 4) {
                    // DM sign
                    Text("⚡️  DAEMON  •  DUNGEON MASTER  ⚡️")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                        .tracking(2)

                    // DM character drawing
                    DMView(armRaised: dmArm)
                        .frame(width: 120, height: 130)

                    // DM speech bubble
                    DMSpeechBubble(text: gs.dmQuote)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)

                Spacer().frame(height: 10)

                // ── TABLE AREA ─────────────────────────────────────────────
                ZStack {
                    // Table shape
                    TableSurface()
                        .frame(height: 200)

                    VStack(spacing: 0) {
                        // Side players row
                        HStack(alignment: .top, spacing: 0) {
                            // Left player
                            PlayerCard(member: npcParty[0])
                                .onTapGesture { showPartyQuote(npcParty[0]) }
                                .frame(width: 90)

                            // Table contents
                            TableContents()
                                .frame(maxWidth: .infinity)

                            // Right player
                            PlayerCard(member: npcParty[1])
                                .onTapGesture { showPartyQuote(npcParty[1]) }
                                .frame(width: 90)
                        }

                        // Bottom player (behind table edge)
                        PlayerCard(member: npcParty[2], horizontal: true)
                            .onTapGesture { showPartyQuote(npcParty[2]) }
                            .padding(.bottom, 8)
                    }
                    .padding(.top, 16)

                    // Party quote bubble
                    if showPartyQuote {
                        Text(partyQuoteText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .offset(y: -60)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Spacer()

                // ── YOUR STATS ─────────────────────────────────────────────
                if let p = gs.player {
                    PlayerHUD(player: p)
                        .padding(.horizontal, 16)
                }

                // ── ACTION BUTTONS ─────────────────────────────────────────
                VStack(spacing: 10) {
                    Button("🌍  VENTURE FORTH") {
                        gs.enterOverworld()
                    }
                    .buttonStyle(MetalButtonStyle(color: Color(red: 0.5, green: 0.1, blue: 0.6)))
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        Button("🎲 DM Says") {
                            gs.randomDMQuote()
                            withAnimation(.spring()) { dmArm.toggle() }
                        }
                        .buttonStyle(MetalButtonStyle(color: Color(red: 0.2, green: 0.2, blue: 0.4)))

                        Button("📖 Party") {
                            let m = npcParty.randomElement()!
                            showPartyQuote(m)
                        }
                        .buttonStyle(MetalButtonStyle(color: Color(red: 0.2, green: 0.35, blue: 0.2)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in flickerA.toggle() }
            Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in flickerB.toggle() }
        }
    }

    private func showPartyQuote(_ member: PartyMember) {
        partyQuoteText = "\"\(member.quote)\"\n— \(member.name)"
        withAnimation(.spring()) { showPartyQuote = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showPartyQuote = false }
        }
    }
}

// MARK: - DM Drawing

struct DMView: View {
    var armRaised: Bool

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let skinColor = Color(red: 0.78, green: 0.62, blue: 0.50)
            let hairColor = Color(red: 0.08, green: 0.06, blue: 0.08)
            let shirtColor = Color.black

            // ── Long hair behind head ──────────────────
            for i in 0..<14 {
                let x = cx - 32 + CGFloat(i) * 5.0
                var p = Path()
                p.move(to: CGPoint(x: x, y: 22))
                let wobble = CGFloat((i % 3) - 1) * 6.0
                p.addCurve(to: CGPoint(x: x + wobble, y: 95),
                           control1: CGPoint(x: x - 6, y: 45),
                           control2: CGPoint(x: x + wobble * 0.5, y: 72))
                ctx.stroke(p, with: .color(hairColor), lineWidth: 3.5)
            }

            // ── Head ──────────────────────────────────
            let headRect = CGRect(x: cx - 22, y: 8, width: 44, height: 48)
            ctx.fill(Circle().path(in: headRect), with: .color(skinColor))

            // ── Eyes (heavy metalhead eyeliner) ───────
            for ex in [cx - 11, cx + 5] {
                let eyeRect = CGRect(x: ex, y: 22, width: 7, height: 7)
                ctx.fill(Circle().path(in: eyeRect), with: .color(.black))
                // eyeliner
                var liner = Path()
                liner.move(to: CGPoint(x: ex - 2, y: 23))
                liner.addLine(to: CGPoint(x: ex + 9, y: 23))
                ctx.stroke(liner, with: .color(.black), lineWidth: 1.5)
            }

            // ── Nose ──────────────────────────────────
            var nose = Path()
            nose.move(to: CGPoint(x: cx - 2, y: 30))
            nose.addLine(to: CGPoint(x: cx - 4, y: 38))
            nose.addLine(to: CGPoint(x: cx + 4, y: 38))
            ctx.stroke(nose, with: .color(skinColor.opacity(0.5)), lineWidth: 1.2)

            // ── Smirk ─────────────────────────────────
            var mouth = Path()
            mouth.move(to: CGPoint(x: cx - 7, y: 43))
            mouth.addQuadCurve(to: CGPoint(x: cx + 7, y: 43),
                               control: CGPoint(x: cx + 3, y: 47))
            ctx.stroke(mouth, with: .color(.black), lineWidth: 1.5)

            // ── Hair flowing beside face ───────────────
            for (side, mult) in [(-1.0, -1.0), (1.0, 1.0)] {
                for s in 0..<7 {
                    var hp = Path()
                    let sx = cx + CGFloat(mult) * (18 + CGFloat(s) * 3)
                    hp.move(to: CGPoint(x: sx, y: 32))
                    hp.addCurve(to: CGPoint(x: sx + CGFloat(side) * CGFloat(s) * 1.5, y: 102),
                                control1: CGPoint(x: sx + CGFloat(mult) * 5, y: 55),
                                control2: CGPoint(x: sx + CGFloat(side) * 4, y: 80))
                    ctx.stroke(hp, with: .color(hairColor), lineWidth: 2.8)
                }
            }

            // ── Body / Band Shirt ─────────────────────
            var body = Path()
            body.move(to: CGPoint(x: cx - 28, y: 57))
            body.addLine(to: CGPoint(x: cx + 28, y: 57))
            body.addLine(to: CGPoint(x: cx + 35, y: 120))
            body.addLine(to: CGPoint(x: cx - 35, y: 120))
            body.closeSubpath()
            ctx.fill(body, with: .color(shirtColor))

            // ── Band logo on shirt ────────────────────
            let shirtText = "IRON DEAD"
            ctx.draw(Text(shirtText)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.red),
                     at: CGPoint(x: cx, y: 84), anchor: .center)
            ctx.draw(Text("☠️ ☠️ ☠️")
                .font(.system(size: 8)),
                     at: CGPoint(x: cx, y: 96), anchor: .center)

            // ── Raised arm (when DM is gesturing) ────
            let armY: CGFloat = armRaised ? 65 : 75
            var arm = Path()
            arm.move(to: CGPoint(x: cx - 28, y: 70))
            arm.addCurve(to: CGPoint(x: cx - 50, y: armY),
                         control1: CGPoint(x: cx - 38, y: 68),
                         control2: CGPoint(x: cx - 45, y: armY + 5))
            ctx.stroke(arm, with: .color(shirtColor), lineWidth: 14)
            ctx.stroke(arm, with: .color(skinColor), lineWidth: 8)

            // Hand
            ctx.fill(Circle().path(in: CGRect(x: cx - 57, y: armY - 6, width: 14, height: 14)),
                     with: .color(skinColor))

            // Right arm (resting on table)
            var rarm = Path()
            rarm.move(to: CGPoint(x: cx + 28, y: 72))
            rarm.addCurve(to: CGPoint(x: cx + 52, y: 80),
                          control1: CGPoint(x: cx + 38, y: 70),
                          control2: CGPoint(x: cx + 46, y: 76))
            ctx.stroke(rarm, with: .color(shirtColor), lineWidth: 14)
            ctx.stroke(rarm, with: .color(skinColor), lineWidth: 8)
            ctx.fill(Circle().path(in: CGRect(x: cx + 46, y: 75, width: 13, height: 13)),
                     with: .color(skinColor))
        }
    }
}

// MARK: - Table Surface

struct TableSurface: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.22, green: 0.13, blue: 0.07))
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.35, green: 0.22, blue: 0.10), lineWidth: 2)
            // Wood grain lines
            Canvas { ctx, size in
                for i in 0..<8 {
                    var p = Path()
                    let y = size.height * CGFloat(i) / 8 + CGFloat.random(in: -3...3)
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y + CGFloat.random(in: -2...2)))
                    ctx.stroke(p, with: .color(Color(red: 0.28, green: 0.17, blue: 0.09)), lineWidth: 0.7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Polyhedral Dice

struct D4DieView: View {
    var body: some View {
        ZStack {
            // Equilateral triangle pointing up
            Canvas { ctx, size in
                let w = size.width, h = size.height
                var tri = Path()
                tri.move(to: CGPoint(x: w / 2, y: 2))
                tri.addLine(to: CGPoint(x: w - 2, y: h - 3))
                tri.addLine(to: CGPoint(x: 2, y: h - 3))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(Color(red: 0.75, green: 0.15, blue: 0.10).opacity(0.88)))
                ctx.stroke(tri, with: .color(Color(red: 1.0, green: 0.55, blue: 0.3)), lineWidth: 1.2)
                // inner highlight line along top edge
                var hl = Path()
                hl.move(to: CGPoint(x: w / 2, y: 4))
                hl.addLine(to: CGPoint(x: w - 5, y: h - 5))
                ctx.stroke(hl, with: .color(Color.white.opacity(0.12)), lineWidth: 0.7)
            }
            .frame(width: 28, height: 26)
            Text("d4")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.9))
                .offset(y: 5)
        }
        .frame(width: 28, height: 26)
    }
}

struct D8DieView: View {
    var body: some View {
        ZStack {
            // Diamond (4-point rhombus)
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                var dia = Path()
                dia.move(to: CGPoint(x: cx, y: 2))
                dia.addLine(to: CGPoint(x: size.width - 2, y: cy))
                dia.addLine(to: CGPoint(x: cx, y: size.height - 2))
                dia.addLine(to: CGPoint(x: 2, y: cy))
                dia.closeSubpath()
                ctx.fill(dia, with: .color(Color(red: 0.10, green: 0.28, blue: 0.68).opacity(0.88)))
                ctx.stroke(dia, with: .color(Color(red: 0.4, green: 0.75, blue: 1.0)), lineWidth: 1.2)
                // centre cross highlight lines
                var hv = Path()
                hv.move(to: CGPoint(x: cx, y: 2)); hv.addLine(to: CGPoint(x: cx, y: cy))
                hv.move(to: CGPoint(x: 2, y: cy)); hv.addLine(to: CGPoint(x: cx, y: cy))
                ctx.stroke(hv, with: .color(Color.white.opacity(0.15)), lineWidth: 0.7)
            }
            .frame(width: 26, height: 30)
            Text("d8")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.9))
        }
        .frame(width: 26, height: 30)
    }
}

struct D12DieView: View {
    var body: some View {
        ZStack {
            // Regular pentagon
            Canvas { ctx, size in
                let cx = size.width / 2, cy = size.height / 2
                let r = min(cx, cy) - 2
                var pent = Path()
                for i in 0..<5 {
                    let angle = CGFloat(i) * .pi * 2 / 5 - .pi / 2
                    let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
                    if i == 0 { pent.move(to: pt) } else { pent.addLine(to: pt) }
                }
                pent.closeSubpath()
                ctx.fill(pent, with: .color(Color(red: 0.08, green: 0.40, blue: 0.18).opacity(0.88)))
                ctx.stroke(pent, with: .color(Color(red: 0.35, green: 1.0, blue: 0.45)), lineWidth: 1.2)
                // top-left edge highlight
                let a0 = CGFloat(-1) * .pi / 2
                let a1 = a0 + .pi * 2 / 5
                var hl = Path()
                hl.move(to: CGPoint(x: cx + r * cos(a0), y: cy + r * sin(a0)))
                hl.addLine(to: CGPoint(x: cx + r * cos(a1), y: cy + r * sin(a1)))
                ctx.stroke(hl, with: .color(Color.white.opacity(0.18)), lineWidth: 0.8)
            }
            .frame(width: 28, height: 28)
            Text("d12")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.9))
        }
        .frame(width: 28, height: 28)
    }
}

// MARK: - Table Contents

struct TableContentsView: View {
    var body: some View {
        VStack(spacing: 4) {
            // Dungeon map sketch
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.9, green: 0.85, blue: 0.7))
                    .frame(width: 80, height: 60)
                Text("🗺️")
                    .font(.system(size: 28))
                Text("MAP")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 0.3, green: 0.2, blue: 0.1))
                    .offset(y: 20)
            }
            // Polyhedral dice
            HStack(spacing: 6) {
                D4DieView()
                D8DieView()
                D12DieView()
            }
            // Books
            HStack(spacing: 3) {
                ForEach([("📕", "DMG"), ("📗", "PHB"), ("📘", "MM")], id: \.0) { icon, label in
                    VStack(spacing: 0) {
                        Text(icon).font(.system(size: 14))
                        Text(label).font(.system(size: 6, design: .monospaced)).foregroundColor(Color(white: 0.5))
                    }
                }
            }
        }
    }
}

struct TableContents: View {
    var body: some View { TableContentsView() }
}

// MARK: - Player Card

struct PlayerCard: View {
    let member: PartyMember
    var horizontal: Bool = false

    var body: some View {
        if horizontal {
            HStack(spacing: 8) {
                Text(member.icon).font(.system(size: 24))
                VStack(alignment: .leading, spacing: 1) {
                    Text(member.name)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(member.color)
                    Text(member.role)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            .padding(8)
            .background(Color(white: 0.08))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(member.color.opacity(0.3), lineWidth: 1))
        } else {
            VStack(spacing: 4) {
                Text(member.icon).font(.system(size: 26))
                Text(member.name)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(member.color)
                Text(member.role)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color(white: 0.35))
                    .lineLimit(1)
            }
            .padding(8)
            .background(Color(white: 0.08))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(member.color.opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - DM Speech Bubble

struct DMSpeechBubble: View {
    let text: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Text("\u{201C}\(text)\u{201D}")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.12, green: 0.08, blue: 0.18))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.25), lineWidth: 1))
                )

            // Tail
            Path { p in
                p.move(to: CGPoint(x: 30, y: 0))
                p.addLine(to: CGPoint(x: 16, y: 12))
                p.addLine(to: CGPoint(x: 44, y: 0))
            }
            .fill(Color(red: 0.12, green: 0.08, blue: 0.18))
            .offset(y: -1)
        }
    }
}

// MARK: - Player HUD

struct PlayerHUD: View {
    let player: Character

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(player.characterClass.icon) \(player.name)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(player.characterClass.color)
                Spacer()
                Text("Lvl \(player.level)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.yellow)
            }

            // HP Bar
            HPBar(current: player.currentHP, max: player.maxHP)

            HStack(spacing: 12) {
                MiniStat(label: "AC",    value: "\(player.armorClass)")
                MiniStat(label: "THAC0", value: "\(player.thac0)")
                MiniStat(label: "Wpn",   value: player.weapon.damageDie == 4 ? "1d4" :
                                                player.weapon.damageDie == 6 ? "1d6" :
                                                player.weapon.damageDie == 8 ? "1d8" :
                                                player.weapon.damageDie == 10 ? "1d10" : "1d12")
                MiniStat(label: "XP",    value: "\(player.experience)")
            }
        }
        .padding(12)
        .background(Color(white: 0.07))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(player.characterClass.color.opacity(0.3), lineWidth: 1))
    }
}

struct HPBar: View {
    let current: Int
    let max: Int

    var fraction: Double { Double(current) / Double(max) }
    var barColor: Color {
        if fraction > 0.6 { return .green }
        if fraction > 0.3 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("HP")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.15)).frame(height: 10)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction, height: 10)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
            .frame(height: 10)
            Text("\(current)/\(max)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(barColor)
        }
    }
}

struct MiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
