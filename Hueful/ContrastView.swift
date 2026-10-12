import SwiftUI

/// How readable text of one color is on another, in plain words (WCAG 2 thresholds).
enum Readability: Comparable {
    case poor, headingsOnly, good, excellent

    init(ratio: Double) {
        self = ratio >= 7 ? .excellent : ratio >= 4.5 ? .good : ratio >= 3 ? .headingsOnly : .poor
    }

    var title: LocalizedStringKey {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .headingsOnly: "Headings Only"
        case .poor: "Poor"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .excellent: "Easy to read for any text, even small print, and for people with low vision."
        case .good: "Fine for body text."
        case .headingsOnly: "Only for large text such as headings, and for icons."
        case .poor: "Hard to read: don't use it for text."
        }
    }

    var color: Color {
        switch self {
        case .excellent: .green
        case .good: .mint
        case .headingsOnly: .orange
        case .poor: .red
        }
    }

    var symbol: String {
        switch self {
        case .excellent: "checkmark.circle.fill"
        case .good: "checkmark.circle"
        case .headingsOnly: "textformat.size.larger"
        case .poor: "xmark.circle.fill"
        }
    }
}

struct ColorPair {
    var text: RGB
    var background: RGB

    var ratio: Double { text.contrast(with: background) }
    var readability: Readability { Readability(ratio: ratio) }
    var ratioText: String { ratio.formatted(.number.precision(.fractionLength(1))) + ":1" }
    var swapped: ColorPair { ColorPair(text: background, background: text) }
}

struct ContrastView: View {
    @Environment(PaletteModel.self) private var palette
    @State private var readableOnly = false

    /// Every two colors of the palette, darker one as text, most readable first.
    private var pairs: [ColorPair] {
        let colors = palette.colors
        return colors.indices.flatMap { i in
            colors.indices.filter { $0 > i }.map { j in
                let (a, b) = (colors[i], colors[j])
                return a.luminance < b.luminance ? ColorPair(text: a, background: b) : ColorPair(text: b, background: a)
            }
        }
        .filter { !readableOnly || $0.readability >= .good }
        .sorted { $0.ratio > $1.ratio }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 0) {
                        ForEach(Array(palette.colors.enumerated()), id: \.offset) { _, rgb in rgb.color }
                    }
                    .frame(height: 44)
                    .clipShape(.rect(cornerRadius: 10))
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
                } footer: {
                    Text("Pairs from the palette in the generator.")
                }

                Section {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                        NavigationLink { ContrastDetailView(pair: pair) } label: { PairRow(pair: pair) }
                    }
                } footer: {
                    Text("Ratings follow the WCAG accessibility guidelines: Excellent is level AAA (7:1 or more), Good is level AA (4.5:1), Headings Only is level AA for large text (3:1).")
                }
            }
            .overlay {
                if pairs.isEmpty {
                    ContentUnavailableView("No Readable Pairs", systemImage: "eye.slash",
                                           description: Text("No two colors of this palette are readable together as text."))
                }
            }
            .navigationTitle("Contrast")
            .toolbar {
                Button(readableOnly ? "Show All Pairs" : "Show Readable Pairs Only",
                       systemImage: readableOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") {
                    readableOnly.toggle()
                }
                .help(readableOnly ? "Show All Pairs" : "Show Readable Pairs Only")
            }
            .animation(.smooth, value: readableOnly)
        }
    }
}

struct PairRow: View {
    let pair: ColorPair

    var body: some View {
        HStack(spacing: 14) {
            Text(verbatim: "Aa")
                .font(.title2.bold())
                .foregroundStyle(pair.text.color)
                .frame(width: 60, height: 60)
                .background(pair.background.color, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: pair.readability.symbol)
                    Text(pair.readability.title)
                }
                .font(.headline)
                .foregroundStyle(pair.readability.color)
                Text(verbatim: "\(pair.text.hex) / \(pair.background.hex)")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(verbatim: pair.ratioText)
                .font(.headline.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

struct ContrastDetailView: View {
    @State var pair: ColorPair

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Heading").font(.largeTitle.bold())
                    Text("The quick brown fox jumps over the lazy dog.")
                    Text("Small print and captions look like this.").font(.caption)
                    HStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                        Image(systemName: "star.fill")
                        Image(systemName: "bell.fill")
                    }
                    .font(.title2)
                    .accessibilityHidden(true)
                }
                .foregroundStyle(pair.text.color)
                .padding(.vertical, 12)
                .listRowBackground(pair.background.color)
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: pair.readability.symbol)
                        Text(pair.readability.title)
                        Spacer()
                        Text(verbatim: pair.ratioText).monospacedDigit().foregroundStyle(.primary)
                    }
                    .font(.title3.bold())
                    .foregroundStyle(pair.readability.color)
                    Text(pair.readability.detail).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                use("Headings and large text", needs: 3)
                use("Icons and buttons", needs: 3)
                use("Body text", needs: 4.5)
                use("Small print and low vision", needs: 7)
            } header: {
                Text("Good For")
            } footer: {
                Text("Large text is at least 18 pt, or 14 pt bold.")
            }
        }
        .navigationTitle(Text(verbatim: "\(pair.text.hex) / \(pair.background.hex)"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            Button("Swap Colors", systemImage: "arrow.up.arrow.down") { pair = pair.swapped }
                .help("Swap Colors")
        }
        .animation(.smooth, value: pair.text)
    }

    private func use(_ title: LocalizedStringKey, needs ratio: Double) -> some View {
        let passes = pair.ratio >= ratio
        return HStack {
            Image(systemName: passes ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(passes ? .green : .red)
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(passes ? Text("Yes") : Text("No"))
    }
}
