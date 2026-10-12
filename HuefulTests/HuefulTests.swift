import Testing
@testable import Hueful

struct HuefulTests {
    @Test func hexRoundTrip() {
        #expect(RGB(hex: "#3FA2C8")?.hex == "#3FA2C8")
        #expect(RGB(hex: "3fa2c8")?.hex == "#3FA2C8")
        #expect(RGB(hex: "#XYZ") == nil)
    }

    @Test func oklchRoundTrip() {
        for hex in ["#3FA2C8", "#FF0000", "#00FF00", "#7F00FF", "#808080"] {
            let (l, c, h) = RGB(hex: hex)!.oklch
            #expect(RGB(l: l, c: c, h: h).hex == hex)
        }
        // Out of gamut: chroma is reduced until it fits, lightness stays.
        let clipped = RGB(l: 0.7, c: 0.4, h: 150)
        #expect(abs(clipped.oklch.l - 0.7) < 0.01)
    }

    @Test func generatedColorsAreDistinct() {
        for harmony in Harmony.allCases {
            let palette = harmony.generate(Array(repeating: nil, count: 6))
            #expect(palette.count == 6)
            #expect(Harmony.closestDistance(palette) >= 0.035)
        }
    }

    @Test func contrastAndNames() {
        #expect(abs(RGB.black.contrast(with: .white) - 21) < 0.01)
        #expect(RGB(hex: "#FE0102")!.name == "Red")
    }

    @Test func harmonyKeepsLockedColors() {
        let locked = RGB(hex: "#123456")!
        for harmony in Harmony.allCases {
            let palette = harmony.generate([nil, locked, nil, nil, nil])
            #expect(palette.count == 5)
            #expect(palette[1] == locked)
        }
    }

    @Test func kMeansFindsMainColors() {
        let points = Array(repeating: RGB.black, count: 30) + Array(repeating: RGB.white, count: 10)
        #expect(RGB.kMeans(points, k: 2) == [.black, .white])
        #expect(RGB.kMeans(Array(repeating: .white, count: 5), k: 3) == [.white])
    }
}
