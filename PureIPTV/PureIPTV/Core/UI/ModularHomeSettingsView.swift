import SwiftUI

public struct ModularHomeSettingsView: View {
    @State private var sections: [HomeSectionConfig] = HomeSectionManager.shared.sections
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($sections) { $sec in
                        HStack(spacing: 12) {
                            Image(systemName: sec.type.icon)
                                .font(.system(size: 18))
                                .foregroundColor(.accentColor)
                                .frame(width: 28)

                            Text(sec.type.title)
                                .font(.body.bold())
                                .foregroundColor(.white)

                            Spacer()

                            Toggle("", isOn: $sec.isVisible)
                                .labelsHidden()
                                .onChange(of: sec.isVisible) { _, _ in
                                    HomeSectionManager.shared.toggleSection(type: sec.type)
                                }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { source, destination in
                        sections.move(fromOffsets: source, toOffset: destination)
                        HomeSectionManager.shared.move(from: source, to: destination)
                    }
                } header: {
                    Text("Ana Ekran Sıralaması ve Görünürlük")
                } footer: {
                    Text("Ana sayfadaki bölümleri yukarı-aşağı sürükleyerek sıralayabilir veya gizleyebilirsiniz.")
                }

                Section {
                    Button("Varsayılana Sıfırla") {
                        HomeSectionManager.shared.resetToDefault()
                        sections = HomeSectionManager.shared.sections
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Ana Ekranı Düzenle")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Kapat") { dismiss() }
                    }
                }
            #endif
        }
    }
}
