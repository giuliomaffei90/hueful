import SwiftUI

struct GeneratorView: View {
    @Environment(PaletteModel.self) private var palette
    #if os(iOS)
    @State private var selected: Slot?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #else
    @State private var selected: Slot.ID?
    @State private var showsInspector = false
    @FocusState private var focused: Bool
    #endif

    var body: some View {
        content
            .animation(.smooth, value: palette.slots)
            .sensoryFeedback(.impact(weight: .light), trigger: palette.colors)
    }

    // MARK: Shared controls

    private var harmonyMenu: some View {
        @Bindable var palette = palette
        return Menu {
            Picker("Harmony", selection: $palette.harmony) {
                ForEach(Harmony.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            Text(palette.harmony.title)
        }
        .help("Harmony")
    }

    private var addButton: some View {
        Button("Add Color", systemImage: "plus", action: palette.add)
            .disabled(palette.slots.count >= PaletteModel.sizes.upperBound)
            .help("Add Color")
    }

    private var saveButton: some View {
        Button("Save Palette…", systemImage: "bookmark") { palette.isSaving = true }
            .help("Save Palette…")
    }

    private var moreMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            #if os(iOS)
            Button("Colors from Photo…", systemImage: "photo") { palette.isImporting = true }
            #else
            Button("Colors from Image…", systemImage: "photo") { palette.isImporting = true }
            #endif
            Button("Copy HEX Codes", systemImage: "doc.on.doc") { copyToPasteboard(palette.hexCodes) }
            Menu("Share", systemImage: "square.and.arrow.up") {
                ShareLink(item: PaletteImage(colors: palette.colors), preview: SharePreview("Palette")) {
                    Label("Share Image", systemImage: "photo")
                }
                ShareLink(item: palette.hexCodes) { Label("Share HEX Codes", systemImage: "number") }
                ShareLink(item: palette.coolorsURL) { Label("Share Coolors Link", systemImage: "link") }
            }
        }
        .help("More")
    }

    /// Side-by-side columns, like the Coolors website. `insets` keeps their text clear of the bars and the notch.
    private func columns(insets: EdgeInsets = EdgeInsets(), select: @escaping (Slot) -> Void) -> some View {
        HStack(spacing: 0) {
            ForEach(palette.slots) { slot in
                SlotColumn(slot: slot, isSelected: isSelected(slot),
                           canRemove: palette.slots.count > PaletteModel.sizes.lowerBound,
                           insets: EdgeInsets(top: insets.top,
                                              leading: slot.id == palette.slots.first?.id ? insets.leading : 0,
                                              bottom: insets.bottom,
                                              trailing: slot.id == palette.slots.last?.id ? insets.trailing : 0),
                           toggleLock: { palette.toggleLock(slot) }, remove: { palette.remove(slot) })
                    .onTapGesture { select(slot) }
                    .draggable(slot.id.uuidString) {
                        RoundedRectangle(cornerRadius: 12).fill(slot.rgb.color).frame(width: 80, height: 120)
                    }
                    .dropDestination(for: String.self) { ids, _ in
                        guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
                        palette.move(id, to: slot.id)
                        return true
                    }
            }
        }
    }

    // MARK: iPhone and iPad: full-width bands (columns when the height is compact), details in a sheet

    #if os(iOS)
    private func isSelected(_ slot: Slot) -> Bool { false }

    private var content: some View {
        Group {
            if verticalSizeClass == .compact {
                GeometryReader { geo in
                    columns(insets: geo.safeAreaInsets) { selected = $0 }
                        .ignoresSafeArea()
                }
            } else {
                bands
            }
        }
        .ignoresSafeArea(.keyboard)
        .safeAreaInset(edge: .bottom) {
            // In landscape the bottom is already taken by the tab bar, so Generate moves to the toolbar.
            if verticalSizeClass != .compact {
                Button("Generate", action: palette.generate)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .padding(.bottom, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { harmonyMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Undo", systemImage: "arrow.uturn.backward", action: palette.undo)
                    .disabled(!palette.canUndo)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                addButton
                saveButton
                moreMenu
            }
            if verticalSizeClass == .compact {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Generate", action: palette.generate)
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { slot in
            if let rgb = palette.binding(for: slot.id) {
                NavigationStack {
                    ColorDetailView(rgb: rgb)
                        .navigationTitle(Text(verbatim: rgb.wrappedValue.name))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .close) { selected = nil }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var bands: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            // Equal bands in the visible area; the first and last also reach under the bars.
            let rowHeight = geo.size.height / CGFloat(palette.slots.count)
            List {
                ForEach(palette.slots) { slot in
                    SlotRow(slot: slot) { palette.toggleLock(slot) }
                        .frame(height: rowHeight)
                        .padding(.top, slot.id == palette.slots.first?.id ? insets.top : 0)
                        .padding(.bottom, slot.id == palette.slots.last?.id ? insets.bottom : 0)
                        .contentShape(.rect)
                        .onTapGesture { selected = slot }
                        .accessibilityAction(named: "Show Details") { selected = slot }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(slot.rgb.color)
                        .swipeActions {
                            if palette.slots.count > PaletteModel.sizes.lowerBound {
                                Button("Remove", systemImage: "trash", role: .destructive) { palette.remove(slot) }
                            }
                        }
                }
                .onMove(perform: palette.move)
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDisabled(true)
            .ignoresSafeArea()
        }
    }

    // MARK: Mac: side-by-side columns, details in the inspector

    #else
    private func isSelected(_ slot: Slot) -> Bool { showsInspector && selected == slot.id }

    private var content: some View {
        columns {
            selected = $0.id
            showsInspector = true
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.space) {
            palette.generate()
            return .handled
        }
        .onAppear { focused = true }
        .navigationTitle("Generate")
        .navigationSubtitle(Text("\(palette.slots.count) colors"))
        .toolbar {
            ToolbarItem { harmonyMenu }
            ToolbarSpacer(.fixed)
            ToolbarItemGroup {
                addButton
                saveButton
                moreMenu
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button("Generate", action: palette.generate)
                    .buttonStyle(.glassProminent)
                    .help("Generate a new palette (Space)")
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button(showsInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing") {
                    showsInspector.toggle()
                }
                .help(showsInspector ? "Hide Inspector" : "Show Inspector")
            }
        }
        .inspector(isPresented: $showsInspector) {
            Group {
                if let selected, let rgb = palette.binding(for: selected) {
                    ColorDetailView(rgb: rgb)
                } else {
                    ContentUnavailableView("No Color Selected", systemImage: "swatchpalette",
                                           description: Text("Click a color to see its values and edit it."))
                }
            }
            .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
    }
    #endif
}

#if os(iOS)
struct SlotRow: View {
    let slot: Slot
    let toggleLock: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: String(slot.rgb.hex.dropFirst()))
                    .font(.title.weight(.semibold).monospaced())
                Text(verbatim: slot.rgb.name)
                    .font(.subheadline)
                    .opacity(0.75)
            }
            Spacer()
            Button(slot.locked ? "Unlock" : "Lock", systemImage: slot.locked ? "lock.fill" : "lock.open", action: toggleLock)
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
                .buttonStyle(.plain)
                .opacity(slot.locked ? 1 : 0.6)
        }
        .padding(.horizontal, 24)
        .foregroundStyle(slot.rgb.onColor)
    }
}
#endif

/// One color as a full-height column, like the Coolors website.
/// On Mac its controls show on hover; on iPhone the lock stays visible and the rest is in the long-press menu.
struct SlotColumn: View {
    let slot: Slot
    let isSelected: Bool
    let canRemove: Bool
    var insets = EdgeInsets()
    let toggleLock: () -> Void
    let remove: () -> Void
    #if os(macOS)
    @State private var hovering = false
    #else
    private let hovering = true
    #endif

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(spacing: 14) {
                #if os(macOS)
                Button("Remove", systemImage: "xmark", action: remove)
                    .opacity(hovering && canRemove ? 1 : 0)
                    .disabled(!canRemove)
                    .help("Remove")
                Button("Copy HEX", systemImage: "doc.on.doc") { copyToPasteboard(slot.rgb.hex) }
                    .opacity(hovering ? 1 : 0)
                    .help("Copy HEX")
                #endif
                Button(slot.locked ? "Unlock" : "Lock", systemImage: slot.locked ? "lock.fill" : "lock.open", action: toggleLock)
                    .opacity(slot.locked ? 1 : hovering ? 0.7 : 0)
                    .help(slot.locked ? "Unlock" : "Lock")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.title2)
            VStack(spacing: 4) {
                Text(verbatim: String(slot.rgb.hex.dropFirst()))
                    .font(.system(.title, design: .monospaced, weight: .semibold))
                    .minimumScaleFactor(0.5)
                Text(verbatim: slot.rgb.name)
                    .font(.callout)
                    .opacity(0.75)
                    .minimumScaleFactor(0.7)
            }
            .lineLimit(1)
            Capsule()
                .frame(width: 24, height: 4)
                .opacity(isSelected ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 24)
        .padding(insets)
        .foregroundStyle(slot.rgb.onColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(slot.rgb.color)
        .contentShape(.rect)
        .contextMenu {
            Button(slot.locked ? "Unlock" : "Lock", systemImage: slot.locked ? "lock.open" : "lock", action: toggleLock)
            Button("Copy HEX", systemImage: "doc.on.doc") { copyToPasteboard(slot.rgb.hex) }
            Button("Remove", systemImage: "trash", role: .destructive, action: remove)
                .disabled(!canRemove)
        }
        #if os(macOS)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        #endif
    }
}
