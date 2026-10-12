import SwiftUI

/// Values, editing, and tints and shades of one color. Shown in a sheet on iPhone and in the inspector on Mac.
struct ColorDetailView: View {
    @Binding var rgb: RGB
    @State private var hexField = ""
    @State private var copied: String?

    var body: some View {
        Form {
            Section {
                rgb.color
                    .frame(height: 140)
                    #if os(macOS)
                    .overlay(alignment: .bottomLeading) {
                        Text(verbatim: rgb.name)
                            .font(.title3.bold())
                            .foregroundStyle(rgb.onColor)
                            .padding(12)
                    }
                    #endif
                    .listRowInsets(EdgeInsets())
            }

            Section("Values") {
                ForEach(rgb.formats, id: \.label) { format in
                    LabeledContent(format.label) {
                        HStack {
                            Text(verbatim: format.value)
                                .monospaced()
                                .textSelection(.enabled)
                            Button(copied == format.value ? "Copied" : "Copy",
                                   systemImage: copied == format.value ? "checkmark" : "doc.on.doc") {
                                copyToPasteboard(format.value)
                                copied = format.value
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Copy")
                        }
                    }
                }
            }

            Section("Edit") {
                ColorPicker("Color", selection: Binding { rgb.color } set: { rgb = RGB($0) }, supportsOpacity: false)
                LabeledContent("HEX") {
                    TextField("HEX", text: $hexField)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .monospaced()
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .onSubmit {
                            if let new = RGB(hex: hexField) { rgb = new } else { hexField = rgb.hex }
                        }
                }
            }

            Section("Tints and Shades") {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(rgb.shades, id: \.self) { shade in
                            Button { rgb = shade } label: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(shade.color)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if shade == rgb { Image(systemName: "checkmark").foregroundStyle(shade.onColor) }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: shade.hex))
                            .help(Text(verbatim: shade.hex))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
        .formStyle(.grouped)
        .onChange(of: rgb, initial: true) { hexField = rgb.hex }
        .sensoryFeedback(.success, trigger: copied)
    }
}
