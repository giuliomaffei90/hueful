import SwiftUI
import SwiftData
import ImageIO
import UniformTypeIdentifiers

struct Slot: Identifiable, Hashable {
    let id = UUID()
    var rgb: RGB
    var locked = false
}

/// The palette of one window, with undo.
@Observable final class PaletteModel {
    static let sizes = 2...10

    var slots: [Slot]
    var harmony = Harmony.automatic
    /// Requests to show the save alert and the image picker, so menu commands and toolbar buttons share them.
    var isSaving = false
    var isImporting = false
    /// The window's undo manager: generating, adding, removing, moving and loading can be undone.
    @ObservationIgnored var undoManager: UndoManager?
    /// Bumped on every change so `canUndo` is re-read.
    private var changes = 0

    init() {
        slots = Harmony.automatic.generate(Array(repeating: nil, count: 5)).map { Slot(rgb: $0) }
    }

    var colors: [RGB] { slots.map(\.rgb) }
    var canUndo: Bool {
        _ = changes
        return undoManager?.canUndo ?? false
    }
    var hexCodes: String { colors.map(\.hex).joined(separator: " ") }
    var coolorsURL: URL { URL(string: "https://coolors.co/" + colors.map { $0.hex.dropFirst() }.joined(separator: "-"))! }

    func generate() {
        let new = harmony.generate(slots.map { $0.locked ? $0.rgb : nil })
        apply(zip(slots, new).map { slot, rgb in
            var slot = slot
            slot.rgb = rgb
            return slot
        }, action: "Generate")
    }

    func load(_ colors: [RGB]) {
        guard !colors.isEmpty else { return }
        apply(colors.map { Slot(rgb: $0) }, action: "Load Palette")
    }

    func add() {
        guard slots.count < Self.sizes.upperBound, let new = harmony.generate(colors + [nil]).last else { return }
        apply(slots + [Slot(rgb: new)], action: "Add Color")
    }

    func remove(_ slot: Slot) {
        guard slots.count > Self.sizes.lowerBound else { return }
        apply(slots.filter { $0.id != slot.id }, action: "Remove Color")
    }

    func move(from source: IndexSet, to destination: Int) {
        var new = slots
        new.move(fromOffsets: source, toOffset: destination)
        apply(new, action: "Move Color")
    }

    /// Moves a color to where another one is (drag and drop).
    func move(_ id: Slot.ID, to target: Slot.ID) {
        guard let from = slots.firstIndex(where: { $0.id == id }),
              let to = slots.firstIndex(where: { $0.id == target }), from != to else { return }
        move(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
    }

    /// The color with this id, for editing it in place.
    func binding(for id: Slot.ID) -> Binding<RGB>? {
        guard slots.contains(where: { $0.id == id }) else { return nil }
        return Binding {
            self.slots.first { $0.id == id }?.rgb ?? .black
        } set: { new in
            if let i = self.slots.firstIndex(where: { $0.id == id }) { self.slots[i].rgb = new }
        }
    }

    func toggleLock(_ slot: Slot) {
        if let i = slots.firstIndex(of: slot) { slots[i].locked.toggle() }
    }

    func undo() { undoManager?.undo() }

    private func apply(_ new: [Slot], action: LocalizedStringResource) {
        let old = slots
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.apply(old, action: action) }
        }
        undoManager?.setActionName(String(localized: action))
        slots = new
        changes += 1
    }
}

@Model final class SavedPalette {
    var name: String
    var hexes: [String]
    var createdAt = Date.now

    init(name: String, hexes: [String]) {
        self.name = name
        self.hexes = hexes
    }

    var colors: [RGB] { hexes.compactMap(RGB.init(hex:)) }
}

extension FocusedValues {
    /// The palette of the key window, for the menu bar commands.
    @Entry var palette: PaletteModel?
}

func copyToPasteboard(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #else
    UIPasteboard.general.string = text
    #endif
}

/// A palette shared as a PNG, rendered only when the share sheet asks for it.
nonisolated struct PaletteImage: Transferable {
    let colors: [RGB]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            try await MainActor.run {
                let data = NSMutableData()
                guard let cgImage = ImageRenderer(content: PaletteStrip(colors: image.colors)).cgImage,
                      let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                CGImageDestinationAddImage(destination, cgImage, nil)
                guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
                return data as Data
            }
        }
    }
}

struct PaletteStrip: View {
    let colors: [RGB]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, rgb in
                rgb.color.overlay(alignment: .bottom) {
                    Text(verbatim: rgb.hex)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundStyle(rgb.onColor)
                        .padding(.bottom, 32)
                }
            }
        }
        .frame(width: 1200, height: 630)
    }
}
