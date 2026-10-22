import SwiftUI

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.english.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Language", "Idioma")) {
                    Picker(L("Language", "Idioma"), selection: $lang) {
                        ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0.rawValue) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Text(L("Tap Edit on the home screen to reorder tiles and rename lamps.",
                           "Toque em Editar na tela inicial para reordenar os blocos e renomear as lâmpadas."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("Settings", "Ajustes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done", "OK")) { dismiss() }
                }
            }
        }
    }
}
