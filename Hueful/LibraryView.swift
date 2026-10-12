import SwiftUI
import SwiftData

struct LibraryView: View {
    let open: () -> Void
    @Query(sort: \SavedPalette.createdAt, order: .reverse) private var saved: [SavedPalette]
    @Environment(\.modelContext) private var context
    @Environment(PaletteModel.self) private var palette
    @State private var renaming: SavedPalette?
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(saved) { item in
                    Button {
                        palette.load(item.colors)
                        open()
                    } label: {
                        SavedRow(item: item)
                    }
                    .tint(.primary)
                    #if os(macOS)
                    .buttonStyle(.plain)
                    #endif
                    .contextMenu {
                        Button("Rename…", systemImage: "pencil") {
                            newName = item.name
                            renaming = item
                        }
                        ShareLink(item: PaletteImage(colors: item.colors), preview: SharePreview(item.name)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) { context.delete(item) }
                    }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(saved[i]) }
                }
            }
            .overlay {
                if saved.isEmpty {
                    ContentUnavailableView("No Saved Palettes", systemImage: "bookmark",
                                           description: Text("Palettes you save from the generator appear here."))
                }
            }
            .navigationTitle("Library")
            .alert("Rename Palette", isPresented: Binding { renaming != nil } set: { if !$0 { renaming = nil } }) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { renaming?.name = newName }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

struct SavedRow: View {
    let item: SavedPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(item.colors.enumerated()), id: \.offset) { _, rgb in rgb.color }
            }
            .frame(height: 56)
            .clipShape(.rect(cornerRadius: 12))
            HStack {
                Text(item.name).font(.headline)
                Spacer()
                Text(item.createdAt, format: .dateTime.day().month().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
