import SwiftUI
import ImageIO

/// An sRGB color with components in 0...1.
nonisolated struct RGB: Hashable, Codable, Sendable {
    var r: Double, g: Double, b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = min(max(r, 0), 1)
        self.g = min(max(g, 0), 1)
        self.b = min(max(b, 0), 1)
    }

    init?(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(r: Double(v >> 16 & 0xFF) / 255, g: Double(v >> 8 & 0xFF) / 255, b: Double(v & 0xFF) / 255)
    }

    /// OKLCH: perceptual lightness (0...1), chroma (colorfulness, ~0...0.37) and hue in degrees.
    /// Out-of-gamut colors keep their lightness and hue and lose just enough chroma to fit in sRGB.
    init(l: Double, c: Double, h: Double) {
        func linear(_ c: Double) -> (Double, Double, Double) {
            let a = c * cos(h * .pi / 180), b = c * sin(h * .pi / 180)
            let l3 = pow(l + 0.3963377774 * a + 0.2158037573 * b, 3)
            let m3 = pow(l - 0.1055613458 * a - 0.0638541728 * b, 3)
            let s3 = pow(l - 0.0894841775 * a - 1.2914855480 * b, 3)
            return (4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
                    -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
                    -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
        }
        func fits(_ v: (Double, Double, Double)) -> Bool { [v.0, v.1, v.2].allSatisfy { (-0.0001...1.0001).contains($0) } }
        var value = linear(c)
        if !fits(value) {
            var low = 0.0, high = c
            for _ in 0..<16 {
                let mid = (low + high) / 2
                if fits(linear(mid)) { low = mid } else { high = mid }
            }
            value = linear(low)
        }
        func encode(_ x: Double) -> Double { x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055 }
        self.init(r: encode(value.0), g: encode(value.1), b: encode(value.2))
    }

    init(_ color: Color) {
        let srgb = color.resolve(in: EnvironmentValues()).cgColor
            .converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?
            .components ?? [0, 0, 0]
        self.init(r: srgb[0], g: srgb[1], b: srgb[2])
    }

    static let black = RGB(r: 0, g: 0, b: 0)
    static let white = RGB(r: 1, g: 1, b: 1)

    var color: Color { Color(red: r, green: g, blue: b) }

    private var bytes: (Int, Int, Int) { (Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded())) }

    var hex: String {
        let (r, g, b) = bytes
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var hsb: (h: Double, s: Double, v: Double) {
        let mx = max(r, g, b), d = mx - min(r, g, b)
        var h = 0.0
        if d > 0 {
            h = switch mx {
            case r: 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6)
            case g: 60 * ((b - r) / d + 2)
            default: 60 * ((r - g) / d + 4)
            }
        }
        return (h < 0 ? h + 360 : h, mx == 0 ? 0 : d / mx, mx)
    }

    var hsl: (h: Double, s: Double, l: Double) {
        let mx = max(r, g, b), mn = min(r, g, b), l = (mx + mn) / 2
        return (hsb.h, mx == mn ? 0 : (mx - mn) / (1 - abs(2 * l - 1)), l)
    }

    var cmyk: (c: Double, m: Double, y: Double, k: Double) {
        let k = 1 - max(r, g, b)
        guard k < 1 else { return (0, 0, 0, 1) }
        return ((1 - r - k) / (1 - k), (1 - g - k) / (1 - k), (1 - b - k) / (1 - k), k)
    }

    /// The color written in the formats people copy into design tools and code.
    var formats: [(label: String, value: String)] {
        func p(_ x: Double) -> Int { Int((x * 100).rounded()) }
        let (r, g, b) = bytes, hsl = hsl, hsb = hsb, cmyk = cmyk
        return [
            ("HEX", hex),
            ("RGB", "rgb(\(r), \(g), \(b))"),
            ("HSL", "hsl(\(Int(hsl.h.rounded())), \(p(hsl.s))%, \(p(hsl.l))%)"),
            ("HSB", "hsb(\(Int(hsb.h.rounded())), \(p(hsb.s))%, \(p(hsb.v))%)"),
            ("CMYK", "cmyk(\(p(cmyk.c))%, \(p(cmyk.m))%, \(p(cmyk.y))%, \(p(cmyk.k))%)"),
        ]
    }

    func mixed(with other: RGB, amount t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    /// Darker shades, the color itself, then lighter tints.
    var shades: [RGB] {
        (1...4).map { mixed(with: .black, amount: Double(5 - $0) * 0.18) } + [self]
            + (1...4).map { mixed(with: .white, amount: Double($0) * 0.18) }
    }

    // MARK: Contrast (WCAG 2)

    private static func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }

    var luminance: Double {
        0.2126 * RGB.linear(r) + 0.7152 * RGB.linear(g) + 0.0722 * RGB.linear(b)
    }

    func contrast(with other: RGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Black or white, whichever reads better on this color.
    var onColor: Color { contrast(with: .black) >= contrast(with: .white) ? .black : .white }

    // MARK: Names

    /// CIE L*a*b*, where distances match how different colors look.
    var lab: (l: Double, a: Double, b: Double) {
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
        let (r, g, b) = (RGB.linear(r), RGB.linear(g), RGB.linear(b))
        let x = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047)
        let y = f(0.2126 * r + 0.7152 * g + 0.0722 * b)
        let z = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
        return (116 * y - 16, 500 * (x - y), 200 * (y - z))
    }

    /// OKLab, the perceptual space the generator works in.
    var oklab: (l: Double, a: Double, b: Double) {
        let (r, g, b) = (RGB.linear(r), RGB.linear(g), RGB.linear(b))
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    var oklch: (l: Double, c: Double, h: Double) {
        let (l, a, b) = oklab
        let h = atan2(b, a) * 180 / .pi
        return (l, (a * a + b * b).squareRoot(), h < 0 ? h + 360 : h)
    }

    /// The closest named color.
    var name: String {
        let (l, a, b) = lab
        return RGB.named.min { p, q in
            pow(p.lab.l - l, 2) + pow(p.lab.a - a, 2) + pow(p.lab.b - b, 2)
                < pow(q.lab.l - l, 2) + pow(q.lab.a - a, 2) + pow(q.lab.b - b, 2)
        }!.name
    }

    // MARK: Photos

    /// The `count` main colors of an image file's data (JPEG, PNG, HEIC…), most common first.
    static func dominant(inImageData data: Data, count: Int) -> [RGB] {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 256] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return [] }
        return dominant(in: image, count: count)
    }

    /// The `count` main colors of an image (k-means on a 48×48 thumbnail), most common first.
    static func dominant(in image: CGImage, count: Int) -> [RGB] {
        let side = 48
        var px = [UInt8](repeating: 0, count: side * side * 4)
        px.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                    bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        let points = stride(from: 0, to: px.count, by: 4).compactMap { i in
            px[i + 3] < 128 ? nil : RGB(r: Double(px[i]) / 255, g: Double(px[i + 1]) / 255, b: Double(px[i + 2]) / 255)
        }
        return kMeans(points, k: count)
    }

    static func kMeans(_ points: [RGB], k: Int, iterations: Int = 10) -> [RGB] {
        guard let first = points.first else { return [] }
        func distance(_ p: RGB, _ q: RGB) -> Double { pow(p.r - q.r, 2) + pow(p.g - q.g, 2) + pow(p.b - q.b, 2) }
        func nearest(_ p: RGB, _ centers: [RGB]) -> Int { centers.indices.min { distance(p, centers[$0]) < distance(p, centers[$1]) }! }

        // Farthest-point seeds: deterministic, and spread across the image's colors.
        var centers = [first]
        while centers.count < k {
            let far = points.max { distance($0, centers[nearest($0, centers)]) < distance($1, centers[nearest($1, centers)]) }!
            if distance(far, centers[nearest(far, centers)]) == 0 { break }
            centers.append(far)
        }
        var counts = [Int]()
        for _ in 0..<iterations {
            var sums = Array(repeating: (0.0, 0.0, 0.0), count: centers.count)
            counts = Array(repeating: 0, count: centers.count)
            for p in points {
                let i = nearest(p, centers)
                sums[i].0 += p.r; sums[i].1 += p.g; sums[i].2 += p.b
                counts[i] += 1
            }
            for i in centers.indices where counts[i] > 0 {
                let n = Double(counts[i])
                centers[i] = RGB(r: sums[i].0 / n, g: sums[i].1 / n, b: sums[i].2 / n)
            }
        }
        return zip(centers, counts).sorted { $0.1 > $1.1 }.map(\.0)
    }
}
