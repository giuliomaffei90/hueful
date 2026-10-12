import Foundation

/// How the generator picks hues: freely (automatic) or by a color-wheel rule.
nonisolated enum Harmony: String, CaseIterable, Identifiable, Sendable {
    case automatic, analogous, monochromatic, complementary, splitComplementary, triadic, square

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .automatic: "Automatic"
        case .analogous: "Analogous"
        case .monochromatic: "Monochromatic"
        case .complementary: "Complementary"
        case .splitComplementary: "Split Complementary"
        case .triadic: "Triadic"
        case .square: "Square"
        }
    }

    /// Hue offsets from the base hue, in degrees, for the color-wheel rules.
    private var hueOffsets: [Double] {
        switch self {
        case .automatic, .monochromatic: [0]
        case .analogous: [-30, -15, 0, 15, 30]
        case .complementary: [0, 180]
        case .splitComplementary: [0, 150, 210]
        case .triadic: [0, 120, 240]
        case .square: [0, 90, 180, 270]
        }
    }

    /// A palette the size of `current`, keeping its non-nil (locked) colors.
    /// Makes many random candidates and returns one of the best-looking, so taste comes from a score, not a fixed rule.
    func generate(_ current: [RGB?]) -> [RGB] {
        let scored = (0..<300).map { _ in
            let palette = candidate(current)
            return (palette, Harmony.score(palette))
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(10).randomElement()!.0
    }

    /// One random palette in OKLCH, where equal steps look equal.
    private func candidate(_ current: [RGB?]) -> [RGB] {
        let n = current.count
        let colorful = current.compactMap { $0?.oklch }.filter { $0.c > 0.04 }

        // Hues: a colorful locked color, if any, is the starting point.
        var hue = colorful.randomElement()?.h ?? .random(in: 0..<360)
        var hues: [Double] = []
        var jumped = false
        for i in 0..<n {
            if self == .automatic {
                // A random walk around the wheel: mostly neighbours, at most one jump for an accent.
                hues.append(hue)
                let jump = !jumped && Double.random(in: 0...1) < 0.25
                jumped = jumped || jump
                hue += jump ? .random(in: 120...200) : .random(in: -35...35)
            } else {
                hues.append(hue + hueOffsets[i * hueOffsets.count / n] + .random(in: -8...8))
            }
        }

        // Lightness: spread from dark to light, as a gradient or mixed.
        let low = Double.random(in: 0.25...0.5), high = min(low + .random(in: 0.3...0.6), 0.94)
        var levels = (0..<n).map { low + (high - low) * Double($0) / Double(max(n - 1, 1)) + .random(in: -0.03...0.03) }
        if Bool.random() { levels.shuffle() } else if Bool.random() { levels.reverse() }

        // Chroma: one mood for the whole palette, from muted to vivid, or the locked colors' mood.
        let lockedMood = colorful.randomElement().flatMap { Bool.random() ? $0.c : nil }
        let mood = lockedMood ?? 0.04 + 0.16 * pow(.random(in: 0...1), 0.8)
        var chromas = (0..<n).map { _ in mood * .random(in: 0.65...1.35) }
        // Often a near-neutral at the lightest or darkest spot, to rest the eye.
        if Double.random(in: 0...1) < 0.35,
           let i = (0..<n).filter({ current[$0] == nil }).max(by: { abs(levels[$0] - 0.6) < abs(levels[$1] - 0.6) }) {
            chromas[i] = .random(in: 0.005...0.03)
        }

        return (0..<n).map { current[$0] ?? RGB(l: levels[$0], c: chromas[$0], h: hues[$0]) }
    }

    /// Higher is better: colors clearly apart, a real light-to-dark range, and even colorfulness.
    static func score(_ palette: [RGB]) -> Double {
        let labs = palette.map(\.oklab), lch = palette.map(\.oklch)
        var closest = 1.0
        for i in labs.indices {
            for j in labs.indices where j > i {
                let d = (pow(labs[i].l - labs[j].l, 2) + pow(labs[i].a - labs[j].a, 2) + pow(labs[i].b - labs[j].b, 2)).squareRoot()
                closest = min(closest, d)
            }
        }
        let lightness = lch.map(\.l)
        let spread = lightness.max()! - lightness.min()!
        let chromas = lch.map(\.c).filter { $0 > 0.04 }
        var unevenness = 0.0
        if chromas.count > 1 {
            let mean = chromas.reduce(0, +) / Double(chromas.count)
            unevenness = (chromas.map { pow($0 - mean, 2) }.reduce(0, +) / Double(chromas.count)).squareRoot() / mean
        }
        return min(closest, 0.15) * 8 + min(spread, 0.45) * 2 - unevenness * 0.4 - (closest < 0.05 ? 5 : 0)
    }
}
