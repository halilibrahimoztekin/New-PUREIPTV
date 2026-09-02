import ComposableArchitecture
import SwiftUI

public struct ProfileSelectionView: View {
    @Bindable var store: StoreOf<ProfileSelectionFeature>
    @State private var newProfileName = ""
    @State private var newProfileIsKids = false

    public init(store: StoreOf<ProfileSelectionFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Kim İzliyor?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 40) {
                    ForEach(store.profiles) { profile in
                        VStack(spacing: 12) {
                            Button {
                                if !store.isEditing {
                                    store.send(.selectProfile(profile))
                                }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: profile.avatarIcon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(profile.isKidsMode ? .orange : .blue)
                                    #if os(iOS)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                        )
                                    #endif

                                    if store.isEditing {
                                        Button {
                                            store.send(.deleteProfile(profile))
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.clipShape(Circle()))
                                                .font(.title2)
                                        }
                                        .offset(x: 10, y: -10)
                                    }
                                }
                            }
                            #if os(tvOS)
                            .buttonStyle(.card)
                            #else
                            .buttonStyle(.plain)
                            #endif

                            Text(profile.name)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    // Add Profile Button
                    VStack(spacing: 12) {
                        Button {
                            store.send(.addProfileTapped)
                        } label: {
                            Image(systemName: "plus")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .frame(width: 100, height: 100)
                                .foregroundColor(.white.opacity(0.5))
                            #if os(iOS)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                )
                            #endif
                        }
                        #if os(tvOS)
                        .buttonStyle(.card)
                        #else
                        .buttonStyle(.plain)
                        #endif

                        Text("Ekle")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 40)

                Button {
                    store.send(.toggleEditMode)
                } label: {
                    Text(store.isEditing ? "Bitti" : "Profilleri Düzenle")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    #if os(iOS)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(.plain)
                .focusable(true)
                #endif
                .padding(.top, 20)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(isPresented: $store.showingAddProfile) {
            NavigationView {
                Form {
                    Section(header: Text("Profil Bilgileri")) {
                        TextField("Profil Adı", text: $newProfileName)
                        Toggle("Çocuk Profili (Sadece Çocuk İçerikleri)", isOn: $newProfileIsKids)
                    }
                }
                .navigationTitle("Yeni Profil")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("İptal") {
                                store.send(.binding(.set(\.showingAddProfile, false)))
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Ekle") {
                                store.send(.addProfile(name: newProfileName, isKidsMode: newProfileIsKids))
                                newProfileName = ""
                                newProfileIsKids = false
                            }
                            .disabled(newProfileName.isEmpty)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }
}
