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
                                .accessibilityLabel(sec.type.title)
                                .accessibilityValue(sec.isVisible ? "Gösteriliyor" : "Gizli")
                                .onChange(of: sec.isVisible) { _, _ in
                                    HomeSectionManager.shared.toggleSection(type: sec.type)
                                }
                        }
                        .padding(.vertical, 4)
                        #if os(tvOS)
                            .contextMenu {
                                if sections.first?.type != sec.type {
                                    Button {
                                        moveSection(sec.type, direction: -1)
                                    } label: {
                                        Label("Yukarı Taşı", systemImage: "arrow.up")
                                    }
                                }
                                if sections.last?.type != sec.type {
                                    Button {
                                        moveSection(sec.type, direction: 1)
                                    } label: {
                                        Label("Aşağı Taşı", systemImage: "arrow.down")
                                    }
                                }
                            }
                        #endif
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
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                #endif
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    #if os(tvOS)
        private func moveSection(_ type: HomeSectionType, direction: Int) {
            guard let index = sections.firstIndex(where: { $0.type == type }) else { return }
            let destination = index + (direction < 0 ? -1 : 2)
            guard destination >= 0, destination <= sections.count else { return }
            let source = IndexSet(integer: index)
            sections.move(fromOffsets: source, toOffset: destination)
            HomeSectionManager.shared.move(from: source, to: destination)
        }
    #endif
}
