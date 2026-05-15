// AmbientAudio.swift
// Synthesizes PCM audio, wraps it in WAV, and plays via AVAudioPlayer(data:).
// No AVAudioEngine complexity — just a looping WAV buffer per mode.

import AVFoundation
import Foundation
#if os(macOS)
import AppKit
#endif

final class AmbientAudio {
    static let shared = AmbientAudio()

    enum Mode: CaseIterable { case overworld, dungeon, combat }

    private var player:      AVAudioPlayer?
    private var pending:     Mode? = nil
    private var cache:       [Mode: Data] = [:]
    private var activeMode:  Mode? = nil
    private let genQueue  = DispatchQueue(label: "audio.gen", qos: .utility)

    /// 0.0 – 1.0.  Changing this live updates the current player immediately.
    var volume: Float = 0.35 {
        didSet { player?.volume = volume }
    }

    var isMuted: Bool = false {
        didSet { player?.volume = isMuted ? 0 : volume }
    }

    private init() {
        // Stop audio cleanly when the app quits (prevents orphaned audio on macOS)
        #if os(macOS)
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        }
        #endif

        // Pre-generate all three modes on a background thread so first play is instant
        genQueue.async { [weak self] in
            guard let self else { return }
            var built: [Mode: Data] = [:]
            for mode in Mode.allCases {
                built[mode] = self.buildWAV(mode: mode)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cache = built
                // Start any mode that was requested while we were generating
                if let p = self.pending {
                    self.pending = nil
                    self.startPlayer(mode: p)
                }
            }
        }
    }

    // MARK: - Public

    func play(_ mode: Mode) {
        guard mode != activeMode else { return }
        activeMode = mode
        if cache[mode] != nil {
            startPlayer(mode: mode)
        } else {
            // Still generating — remember the request; init() will start it
            pending = mode
        }
    }

    func stop() {
        activeMode = nil
        pending    = nil
        player?.stop()
        player = nil
    }

    // MARK: - Playback

    private func startPlayer(mode: Mode) {
        guard let data = cache[mode] else { return }
        player?.stop()
        do {
            let p = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            p.numberOfLoops = -1
            p.volume        = isMuted ? 0 : volume
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            print("AmbientAudio: AVAudioPlayer failed – \(error)")
        }
    }

    // MARK: - Synthesis + WAV encoding

    private func buildWAV(mode: Mode) -> Data {
        let sr    = 44_100
        let secs  = 10.0                  // 10-second loop
        let total = Int(Double(sr) * secs)
        let spec  = AudioSpec(mode: mode)

        var buf = [Float](repeating: 0, count: total)

        // ── Drone ──────────────────────────────────────────────────────────
        let f0 = spec.droneFreq
        for i in 0..<total {
            let t = Double(i) / Double(sr)
            var s  = 0.14 * sin(2 * .pi * f0 * t)
            s     += 0.07 * sin(4 * .pi * f0 * t)
            s     += 0.04 * sin(6 * .pi * f0 * t)
            s     += 0.03 * sin(2 * .pi * (f0 * 1.0031) * t)   // slight chorus
            s     *= 0.87 + 0.13 * sin(2 * .pi * 0.17 * t)     // tremolo LFO
            buf[i] += Float(s)
        }

        // ── Melody ─────────────────────────────────────────────────────────
        if !spec.melody.isEmpty {
            var noteIdx     = 0
            var noteSamples = 0
            let noteLen = Int(Double(sr) * spec.noteDur)

            for i in 0..<total {
                let freq = spec.melody[noteIdx]
                let prog = Double(noteSamples) / Double(noteLen)
                var env  = 1.0
                if prog < 0.07  { env = prog / 0.07 }
                else if prog > 0.65 { env = max(0, (1.0 - prog) / 0.35) }

                let t = Double(noteSamples) / Double(sr)
                buf[i] += Float(env * 0.08 * sin(2 * .pi * freq * t))

                noteSamples += 1
                if noteSamples >= noteLen {
                    noteSamples = 0
                    noteIdx = (noteIdx + 1) % spec.melody.count
                }
            }
        }

        // ── Fade in/out so the loop join is seamless ───────────────────────
        let fadeLen = min(Int(Double(sr) * 0.4), total / 4)
        for i in 0..<fadeLen {
            let g = Float(i) / Float(fadeLen)
            buf[i]            *= g
            buf[total - 1 - i] *= g
        }

        // ── Pack as 16-bit mono WAV ────────────────────────────────────────
        return encodeWAV(samples: buf, sampleRate: sr)
    }

    private func encodeWAV(samples: [Float], sampleRate: Int) -> Data {
        let channels    = 1
        let bitsPerSmp  = 16
        let byteRate    = sampleRate * channels * bitsPerSmp / 8
        let blockAlign  = channels * bitsPerSmp / 8
        let dataBytes   = samples.count * 2

        var d = Data()
        d.reserveCapacity(44 + dataBytes)

        func str(_ s: String) { d.append(contentsOf: s.utf8) }
        func i16(_ v: Int16)  { var x = v.littleEndian;  withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func i32(_ v: Int32)  { var x = v.littleEndian;  withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }

        str("RIFF"); i32(Int32(36 + dataBytes)); str("WAVE")
        str("fmt "); i32(16); i16(1)                          // PCM
        i16(Int16(channels)); i32(Int32(sampleRate))
        i32(Int32(byteRate)); i16(Int16(blockAlign)); i16(Int16(bitsPerSmp))
        str("data"); i32(Int32(dataBytes))

        for s in samples {
            let clamped = max(-1.0, min(1.0, s))
            i16(Int16(clamped * 32_000))     // 32000 leaves headroom
        }
        return d
    }
}

// MARK: - Per-mode audio spec

private struct AudioSpec {
    let droneFreq: Double
    let melody:    [Double]
    let noteDur:   Double

    init(mode: AmbientAudio.Mode) {
        switch mode {

        // A-minor — open, mysterious overworld
        case .overworld:
            droneFreq = 55.0      // A2
            noteDur   = 0.95
            melody    = [110.00, 130.81, 146.83, 164.81,
                         196.00, 220.00, 196.00, 164.81,
                         146.83, 130.81, 110.00, 164.81,
                         220.00, 196.00, 164.81, 146.83]

        // E-minor — dark, slow dungeon crawl
        case .dungeon:
            droneFreq = 41.20     // E2
            noteDur   = 1.20
            melody    = [ 82.41,  98.00, 110.00, 123.47,
                         146.83, 164.81, 146.83, 123.47,
                         110.00,  98.00,  82.41, 123.47,
                         146.83, 164.81, 123.47, 110.00]

        // D-minor — tense combat arpeggio
        case .combat:
            droneFreq = 36.71     // D2
            noteDur   = 0.42
            melody    = [ 73.42,  87.31, 110.00, 130.81,
                         110.00,  87.31,  73.42, 110.00,
                         130.81,  87.31,  73.42, 110.00,
                          87.31,  73.42, 130.81, 110.00]
        }
    }
}
