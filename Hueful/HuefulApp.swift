import SwiftUI
import SwiftData
import PhotosUI

@main
struct HuefulApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SavedPalette.self)
        #if os(macOS)
        .defaultSize(width: 1100, height: 680)
        .commands {
            SidebarCommands()
            InspectorCommands()
            PaletteCommands()
        }
        #endif
    }
}

enum AppTab { case generate, library, contrast }

/// One window: its own palette, shared by the three sections. Tabs on iPhone, a sidebar on iPad and Mac.
struct ContentView: View {
    @State private var palette = PaletteModel()
    @State private var tab = AppTab.generate
    @State private var name = ""
    @State private var saves = 0
    #if os(iOS)
    @State private var photo: PhotosPickerItem?
    #endif
    @Environment(\.undoManager) private var undoManager
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var palette = palette
        TabView(selection: $tab) {
            Tab("Generate", systemImage: "swatchpalette", value: .generate) {
                NavigationStack { GeneratorView() }
            }
            Tab("Library", systemImage: "bookmark", value: .library) {
                LibraryView { tab = .generate }
            }
            Tab("Contrast", systemImage: "circle.lefthalf.filled", value: .contrast) {
                ContrastView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(palette)
        .focusedSceneValue(\.palette, palette)
        .onChange(of: undoManager, initial: true) { palette.undoManager = undoManager }
        .sensoryFeedback(.success, trigger: saves)
        .alert("Save Palette", isPresented: $palette.isSaving) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let title = name.trimmingCharacters(in: .whitespaces)
                context.insert(SavedPalette(name: title.isEmpty ? String(localized: "Untitled Palette") : title,
                                            hexes: palette.colors.map(\.hex)))
                saves += 1
            }
        }
        .onChange(of: palette.isSaving) { if palette.isSaving { name = "" } }
        #if os(iOS)
        .photosPicker(isPresented: $palette.isImporting, selection: $photo, matching: .images)
        .task(id: photo) {
            guard let photo, let data = try? await photo.loadTransferable(type: Data.self) else { return }
            palette.load(RGB.dominant(inImageData: data, count: palette.slots.count))
            tab = .generate
            self.photo = nil
        }
        #else
        .fileImporter(isPresented: $palette.isImporting, allowedContentTypes: [.image]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            palette.load(RGB.dominant(inImageData: data, count: palette.slots.count))
            tab = .generate
        }
        #endif
    }
}

#if os(macOS)
/// The Palette menu: every generator action, for the key window.
struct PaletteCommands: Commands {
    @FocusedValue(\.palette) private var palette

    var body: some Commands {
        CommandMenu("Palette") {
            Group {
                Button("Generate") { palette?.generate() }
                    .keyboardShortcut("g")
                Button("Add Color") { palette?.add() }
                    .disabled((palette?.slots.count ?? .max) >= PaletteModel.sizes.upperBound)
                Picker("Harmony", selection: Binding { palette?.harmony ?? .automatic } set: { palette?.harmony = $0 }) {
                    ForEach(Harmony.allCases) { Text($0.title).tag($0) }
                }
                Divider()
                Button("Save Palette…") { palette?.isSaving = true }
                    .keyboardShortcut("s")
                Button("Colors from Image…") { palette?.isImporting = true }
                    .keyboardShortcut("o")
                Button("Copy HEX Codes") { palette.map { copyToPasteboard($0.hexCodes) } }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            .disabled(palette == nil)
        }
    }
}
#endif
