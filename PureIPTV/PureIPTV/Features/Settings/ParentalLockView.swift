import ComposableArchitecture
import SwiftUI

public struct ParentalLockView: View {
    @Bindable var store: StoreOf<ParentalLockFeature>
    @FocusState private var isFocused: Bool

    public init(store: StoreOf<ParentalLockFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .padding(.top, 40)

                Text(AppStrings.ParentalLock.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(AppStrings.ParentalLock.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                SecureField("PIN", text: Binding(
                    get: { store.pinInput },
                    set: { store.send(.pinInputChanged($0)) }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.largeTitle)
                .focused($isFocused)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 40)

                if let error = store.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Spacer()
            }
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        store.send(.cancelTapped)
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
                isFocused = true
            }
        }
    }
}
