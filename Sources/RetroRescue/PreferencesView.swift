import SwiftUI

/// K18: Preferences panel for RetroRescue.
struct PreferencesView: View {
    @AppStorage("defaultViewMode") private var defaultViewMode = "list"
    @AppStorage("hexDumpMaxBytes") private var hexDumpMaxBytes = 4096
    @AppStorage("autoExtractOnImport") private var autoExtractOnImport = false
    @AppStorage("preserveResourceForks") private var preserveResourceForks = true
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Preferences").font(.headline).padding()
            Divider()
            Form {
                Section("General") {
                    Picker("Default view mode", selection: $defaultViewMode) {
                        Text("List").tag("list")
                        Text("Grid").tag("grid")
                        Text("Columns").tag("columns")
                    }
                    Toggle("Auto-extract archives on import", isOn: $autoExtractOnImport)
                    Toggle("Show hidden files (._files)", isOn: $showHiddenFiles)
                }
                Section("Preview") {
                    Picker("Hex dump size", selection: $hexDumpMaxBytes) {
                        Text("1 KB").tag(1024)
                        Text("4 KB").tag(4096)
                        Text("16 KB").tag(16384)
                        Text("64 KB").tag(65536)
                    }
                }
                Section("Export") {
                    Toggle("Preserve resource forks (xattr)", isOn: $preserveResourceForks)
                }
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 300)
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}
