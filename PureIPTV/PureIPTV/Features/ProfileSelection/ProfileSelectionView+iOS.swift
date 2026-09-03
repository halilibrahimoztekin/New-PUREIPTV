#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS Profile Selection View

    public struct ProfileSelectionView_iOS: View {
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

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 32) {
                        ForEach(store.profiles) { profile in
                            VStack(spacing: 12) {
                                Button {
                                    if !store.isEditing {
                                        store.send(.selectProfile(profile))
                                    }
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: profile.avatarIcon.isEmpty ? "person.crop.circle.fill" : profile.avatarIcon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 90, height: 90)
                                            .foregroundColor(profile.isKidsMode ? .orange : .blue)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                            )

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
                                .buttonStyle(.plain)

                                Text(profile.name)
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }

                        // Add Profile Button
                        if !store.isEditing, store.profiles.count < 6 {
                            VStack(spacing: 12) {
                                Button {
                                    store.send(.addProfileTapped)
                                } label: {
                                    Image(systemName: "plus")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 36, height: 36)
                                        .frame(width: 90, height: 90)
                                        .foregroundColor(.white.opacity(0.5))
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)

                                Text("Ekle")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(.horizontal, 40)

                    Button {
                        store.send(.toggleEditMode)
                    } label: {
                        Text(store.isEditing ? "Bitti" : "Profilleri Düzenle")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
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
                    .navigationBarTitleDisplayMode(.inline)
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
#endif
