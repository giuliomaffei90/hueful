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
    /// Colors are drawn from distributions measured on 250 Coolors palettes; near-identical colors are rejected.
    func generate(_ current: [RGB?]) -> [RGB] {
        var palette = candidate(current)
        for _ in 0..<100 where Harmony.closestDistance(palette) < 0.035 {
            palette = candidate(current)
        }
        return palette
    }

    /// One random palette in OKLCH, where equal steps look equal.
    private func candidate(_ current: [RGB?]) -> [RGB] {
        let free = current.indices.filter { current[$0] == nil }
        guard !free.isEmpty else { return current.compactMap { $0 } }
        let n = free.count
        let colorful = current.compactMap { $0?.oklch }.filter { $0.c > 0.04 }

        // Hues: a few families around a base hue (a colorful locked color, if any).
        // About 4 in 10 Coolors palettes stay within one family.
        let base = colorful.randomElement()?.h ?? .random(in: 0..<360)
        let families: [Double] = (self == .automatic
            ? [0] + (0..<Harmony.pick([30, 38, 24, 8])).map { _ in (Bool.random() ? 1 : -1) * .random(in: 40...180) }
            : hueOffsets).sorted().map { base + $0 }
        // Each family takes a run of neighbouring lightness levels, so the hue drifts along the gradient
        // instead of jumping back and forth. Every family gets at least one color when there is room.
        var familyOf = (Array(families.indices) + (0..<max(n - families.count, 0)).map { _ in families.indices.randomElement()! })
            .prefix(n).sorted()
        if Bool.random() { familyOf.reverse() }

        // Lightness: a random range, from narrow to wide, with colors at both ends and more of them on the light side.
        let low = Double.random(in: 0.15...0.55), high = min(low + .random(in: 0.3...0.75), 0.99)
        let levels = ([low, high] + (0..<max(n - 2, 0)).map { _ in low + (high - low) * pow(.random(in: 0...1), 0.7) })
            .prefix(n).sorted()

        // Chroma: mostly muted, one mood for the palette (or the locked colors' mood) and uneven around it.
        let mood = colorful.randomElement()?.c ?? 0.035 + 0.15 * pow(.random(in: 0...1), 1.3)
        var chromas = levels.map { _ in mood * .random(in: 0.4...1.6) }
        // Up to four near-neutrals, at the lightest and darkest ends, like the greys and creams of real palettes.
        let neutrals = min(Harmony.pick([50, 30, 14, 5, 1]), n)
        for i in levels.indices.sorted(by: { abs(levels[$0] - 0.6) > abs(levels[$1] - 0.6) }).prefix(neutrals) {
            chromas[i] = .random(in: 0...0.025)
        }

        var colors = levels.indices.map { i in
            RGB(l: levels[i], c: chromas[i], h: families[familyOf[i]] + .random(in: -15...15))
        }
        // Order: usually from light to dark or the reverse, often with one pair swapped, sometimes mixed.
        if Bool.random() { colors.reverse() }
        switch Double.random(in: 0...1) {
        case ..<0.3: colors.shuffle()
        case ..<0.6 where n > 1: colors.swapAt(Int.random(in: 0..<n - 1), Int.random(in: 0..<n - 1) + 1)
        default: break
        }

        var palette = current
        for (slot, color) in zip(free, colors) { palette[slot] = color }
        return palette.compactMap { $0 }
    }

    /// An index drawn with the given relative weights.
    private static func pick(_ weights: [Int]) -> Int {
        var r = Int.random(in: 0..<weights.reduce(0, +))
        for (i, weight) in weights.enumerated() {
            if r < weight { return i }
            r -= weight
        }
        return 0
    }

    /// The OKLab distance between the two most similar colors of a palette.
    static func closestDistance(_ palette: [RGB]) -> Double {
        let labs = palette.map(\.oklab)
        var closest = Double.infinity
        for i in labs.indices {
            for j in labs.indices where j > i {
                closest = min(closest, (pow(labs[i].l - labs[j].l, 2) + pow(labs[i].a - labs[j].a, 2)
                                        + pow(labs[i].b - labs[j].b, 2)).squareRoot())
            }
        }
        return closest
    }
}
