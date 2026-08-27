import ComposableArchitecture
import SwiftUI

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("GÜVENLİK")) {
                    Toggle(isOn: Binding(
                        get: { store.isParentalControlEnabled },
                        set: { store.send(.toggleParentalControl($0)) }
                    )) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.red)
                            Text("Ebeveyn Kontrolü")
                        }
                    }
                    .tint(.red)
                }

                Section(header: Text("HAKKINDA"), footer: Text("PureIPTV v1.0.0")) {
                    HStack {
                        Text("Sürüm")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(isPresented: $store.isShowingPINSetup) {
                PINSetupView(store: store)
                #if os(iOS)
                    .presentationDetents([.height(300)])
                #endif
            }
        }
    }
}

struct PINSetupView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(store.step == .enterNew ? "Yeni PIN Belirleyin" : "PIN'i Doğrulayın")
                    .font(.headline)

                SecureField("PIN", text: Binding(
                    get: { store.step == .enterNew ? store.pinInput : store.pinConfirm },
                    set: { store.send(.pinInputChanged($0)) }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.largeTitle)
                .focused($isFocused)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if let error = store.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Ebeveyn Kontrolü")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        store.send(.cancelPINSetup)
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
