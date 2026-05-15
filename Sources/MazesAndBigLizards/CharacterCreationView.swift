import SwiftUI

struct CharacterCreationView: View {
    @EnvironmentObject var gs: GameState

    @State private var name: String = "Janak"
    private let nameOptions = ["Janak", "Sonja", "Harald"]
    @State private var selectedClass: CharacterClass = .fighter
    @State private var selectedRace: CharacterRace = .human
    @State private var stats: (str: Int, dex: Int, con: Int, int: Int, wis: Int, cha: Int) = (10, 10, 10, 10, 10, 10)
    @State private var rolling: Bool = false
    @State private var rollAnimation: Int = 0

    var previewAC: Int {
        var str = stats.str, dex = stats.dex, con = stats.con, cha = stats.cha
        selectedRace.applyBonuses(str: &str, dex: &dex, con: &con, cha: &cha)
        return selectedClass.startingAC - max(0, (dex - 10) / 2)
    }

    var previewTHAC0: Int { selectedClass.thac0(atLevel: 1) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.03, blue: 0.1),
                                    Color(red: 0.08, green: 0.05, blue: 0.12)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Outer VStack keeps the name field above (and outside) the ScrollView
            // so macOS NSScrollView doesn't intercept key events from NSTextField.
            VStack(spacing: 0) {
                Text("📜 CHARACTER CREATION")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(.vertical, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("CHARACTER NAME").sectionLabel()
                    Picker("", selection: $name) {
                        ForEach(nameOptions, id: \.self) { n in
                            Text(n)
                                .font(.system(.body, design: .monospaced))
                                .tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .padding(8)
                    .background(Color(white: 0.12))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(white: 0.3), lineWidth: 1))
                    .foregroundColor(.white)
                    .accentColor(.yellow)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 20) {
                    // Class selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CLASS").sectionLabel()
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(CharacterClass.allCases, id: \.self) { cls in
                                ClassCard(cls: cls, selected: selectedClass == cls)
                                    .onTapGesture { selectedClass = cls }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Race selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RACE").sectionLabel()
                        HStack(spacing: 8) {
                            ForEach(CharacterRace.allCases, id: \.self) { race in
                                RaceButton(race: race, selected: selectedRace == race)
                                    .onTapGesture { selectedRace = race }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Stats
                    VStack(spacing: 10) {
                        HStack {
                            Text("ABILITY SCORES").sectionLabel()
                            Spacer()
                            Button(rolling ? "🎲 Rolling..." : "🎲 Roll Stats") {
                                rollStats()
                            }
                            .font(.system(size: 12, design: .monospaced).bold())
                            .foregroundColor(.yellow)
                            .disabled(rolling)
                        }

                        StatsGrid(stats: stats)

                        // Preview stats
                        HStack(spacing: 20) {
                            StatPill(label: "AC", value: previewAC, color: .cyan)
                            StatPill(label: "THAC0", value: previewTHAC0, color: .orange)
                            StatPill(label: "Weapon", value: nil, text: selectedClass.startingWeapon.name, color: .purple)
                        }
                    }
                    .padding(.horizontal, 24)

                    // DM note
                    HStack {
                        Text("🤘")
                        Text("\"Good stats. Mediocre chance of survival.\"")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                            .italic()
                    }

                    // Begin button
                    Button("BEGIN ADVENTURE ⚔️") {
                        let n = name
                        var s = stats
                        selectedRace.applyBonuses(str: &s.str, dex: &s.dex, con: &s.con, cha: &s.cha)
                        let character = Character(
                            name: n, race: selectedRace, characterClass: selectedClass,
                            str: max(3, s.str), dex: max(3, s.dex), con: max(3, s.con),
                            int: max(3, s.int), wis: max(3, s.wis), cha: max(3, s.cha)
                        )
                        gs.startGame(character: character)
                    }
                    .buttonStyle(MetalButtonStyle(color: Color(red: 0.6, green: 0.1, blue: 0.7)))
                    .padding(.bottom, 40)
                }
            }
            } // outer VStack
        }
        .onAppear { rollStats() }
    }

    private func rollStats() {
        rolling = true
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { timer in
            stats = (Character.rollStat(), Character.rollStat(), Character.rollStat(),
                     Character.rollStat(), Character.rollStat(), Character.rollStat())
            count += 1
            if count >= 15 { timer.invalidate(); rolling = false }
        }
    }
}

// MARK: - Subviews

struct ClassCard: View {
    let cls: CharacterClass
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(cls.icon).font(.system(size: 20))
                Text(cls.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(selected ? cls.color : .white)
            }
            Text(cls.classDescription)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? cls.color.opacity(0.2) : Color(white: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? cls.color : Color(white: 0.2), lineWidth: selected ? 2 : 1))
        )
    }
}

struct RaceButton: View {
    let race: CharacterRace
    let selected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(race.icon).font(.system(size: 22))
            Text(race.rawValue)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(selected ? .yellow : Color(white: 0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Color.yellow.opacity(0.15) : Color(white: 0.08))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.yellow : Color(white: 0.2), lineWidth: selected ? 2 : 1))
        )
    }
}

struct StatsGrid: View {
    let stats: (str: Int, dex: Int, con: Int, int: Int, wis: Int, cha: Int)

    var body: some View {
        let pairs: [(String, Int)] = [
            ("STR", stats.str), ("DEX", stats.dex), ("CON", stats.con),
            ("INT", stats.int), ("WIS", stats.wis), ("CHA", stats.cha),
        ]
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(pairs, id: \.0) { label, value in
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                    Text("\(value)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(statColor(value))
                    Text(modifier(value))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(white: 0.1))
                .cornerRadius(6)
            }
        }
    }

    func statColor(_ v: Int) -> Color {
        if v >= 16 { return .green }
        if v >= 13 { return .yellow }
        if v >= 9  { return .white }
        return .red
    }

    func modifier(_ v: Int) -> String {
        let m = (v - 10) / 2
        return m >= 0 ? "+\(m)" : "\(m)"
    }
}

struct StatPill: View {
    let label: String
    let value: Int?
    var text: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.5))
            if let v = value {
                Text("\(v)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(color)
            } else if let t = text {
                Text(t)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.4), lineWidth: 1))
    }
}


extension Text {
    func sectionLabel() -> some View {
        self.font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(Color(white: 0.45))
            .tracking(2)
    }
}
