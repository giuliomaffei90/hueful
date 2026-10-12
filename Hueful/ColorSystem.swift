import Foundation

/// A physical color collection (paints, inks, pencils) and the closest of its colors to any color.
nonisolated struct ColorSystem: Sendable {
    struct Swatch: Sendable {
        let code: String
        let rgb: RGB
        let lab: (l: Double, a: Double, b: Double)
    }

    let title: String
    let swatches: [Swatch]

    /// `data` has one color per line: the HEX value, a space, then the code and name.
    init(_ title: String, _ data: String) {
        self.title = title
        swatches = data.split(separator: "\n").compactMap { line in
            let line = line.trimmingCharacters(in: .whitespaces)
            guard let rgb = RGB(hex: String(line.prefix(6))) else { return nil }
            return Swatch(code: String(line.dropFirst(7)), rgb: rgb, lab: rgb.oklab)
        }
    }

    /// The swatch that looks closest, measured in OKLab.
    func nearest(to rgb: RGB) -> Swatch {
        let (l, a, b) = rgb.oklab
        return swatches.min { p, q in
            pow(p.lab.l - l, 2) + pow(p.lab.a - a, 2) + pow(p.lab.b - b, 2)
                < pow(q.lab.l - l, 2) + pow(q.lab.a - a, 2) + pow(q.lab.b - b, 2)
        }!
    }
}
