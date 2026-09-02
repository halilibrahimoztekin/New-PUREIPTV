#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS & iPad Add Playlist View

    public struct AddPlaylistView_iOS: View {
        @Bindable var store: StoreOf<AddPlaylistFeature>
        @FocusState private var focusedField: Field?

        private enum Field: Hashable {
            case serverURL, username, password, m3uURL
        }

        public init(store: StoreOf<AddPlaylistFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                // ── OLED base + ambient glow ─────────────────────────────
                Color.black.ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color(hex: "#0A84FF").opacity(0.12),
                        Color(hex: "#BF5AF2").opacity(0.06),
                        Color.clear,
                    ],
                    center: .init(x: 0.5, y: 0.25),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                // ── Scrollable content ───────────────────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        header
                            .padding(.top, 56)
                            .padding(.bottom, 40)

                        // Type picker
                        typePicker
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 32)

                        // Form fields
                        formFields
                            .padding(.horizontal, horizontalPadding)

                        // Error banner
                        if let error = store.errorMessage {
                            errorBanner(message: error)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, 16)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Connect button
                        connectButton
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 32)
                            .padding(.bottom, 48)
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.errorMessage)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.playlistType)
            .onTapGesture {
                focusedField = nil
            }
        }

        // MARK: – Header

        private var header: some View {
            VStack(spacing: 12) {
                // Logo icon
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#BF5AF2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Playlist Ekle")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(hex: "#E4E1E7"))

                Text("Xtream Codes bilgilerinizi veya M3U adresinizi girin")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }

        // MARK: – Type Picker

        private var typePicker: some View {
            HStack(spacing: 0) {
                ForEach(PlaylistType.allCases, id: \.self) { type in
                    Button {
                        store.send(.playlistTypeChanged(type))
                    } label: {
                        Text(type.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                store.playlistType == type
                                    ? Color.white
                                    : Color(hex: "#C0C6D6").opacity(0.6)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                if store.playlistType == type {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(hex: "#0A84FF"))
                                        .matchedGeometryEffect(id: "pill", in: pickerNamespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }

        @Namespace private var pickerNamespace

        // MARK: – Form Fields

        @ViewBuilder
        private var formFields: some View {
            if store.playlistType == .xtream {
                VStack(spacing: 12) {
                    GlassTextField(
                        icon: "server.rack",
                        placeholder: "Sunucu URL (https://provider.net:8080)",
                        text: $store.serverURL,
                        keyboardType: .URL,
                        autocapitalization: .never
                    )
                    .focused($focusedField, equals: .serverURL)

                    HStack(spacing: 12) {
                        GlassTextField(
                            icon: "person.fill",
                            placeholder: "Kullanıcı Adı",
                            text: $store.username,
                            autocapitalization: .never
                        )
                        .focused($focusedField, equals: .username)

                        GlassSecureField(
                            icon: "lock.fill",
                            placeholder: "Şifre",
                            text: $store.password,
                            isVisible: store.isPasswordVisible,
                            onToggle: { store.send(.togglePasswordVisibility) }
                        )
                        .focused($focusedField, equals: .password)
                    }
                }
            } else {
                GlassTextField(
                    icon: "link",
                    placeholder: "M3U URL (http://...)",
                    text: $store.m3uURL,
                    keyboardType: .URL,
                    autocapitalization: .never
                )
                .focused($focusedField, equals: .m3uURL)
            }
        }

        // MARK: – Error Banner

        private func errorBanner(message: String) -> some View {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color(hex: "#FF453A"))
                    .font(.system(size: 16, weight: .semibold))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#E4E1E7"))
                    .multilineTextAlignment(.leading)

                Spacer()

                Button {
                    store.send(.dismissError)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.6))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#FF453A").opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: "#FF453A").opacity(0.3), lineWidth: 1)
                    )
            )
        }

        // MARK: – Connect Button

        private var connectButton: some View {
            Button {
                focusedField = nil
                store.send(.connectTapped)
            } label: {
                ZStack {
                    if store.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Bağlan")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Group {
                        if store.canConnect, !store.isLoading {
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#0060CC")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color(hex: "#1F1F23")
                        }
                    }
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(store.canConnect ? 0 : 0.06), lineWidth: 1)
                )
                .opacity(store.canConnect ? 1 : 0.5)
            }
            .disabled(!store.canConnect || store.isLoading)
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.canConnect)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.isLoading)
        }

        // MARK: – Layout helpers

        private var horizontalPadding: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 80 : 20
        }
    }

    // MARK: - Glass Text Field

    struct GlassTextField: View {
        let icon: String
        let placeholder: String
        @Binding var text: String
        var keyboardType: UIKeyboardType = .default
        var autocapitalization: TextInputAutocapitalization = .sentences

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: "#0A84FF"))
                    .frame(width: 22)

                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#E4E1E7"))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .tint(Color(hex: "#0A84FF"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Glass Secure Field

    struct GlassSecureField: View {
        let icon: String
        let placeholder: String
        @Binding var text: String
        let isVisible: Bool
        let onToggle: () -> Void

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(hex: "#0A84FF"))
                    .frame(width: 22)

                if isVisible {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#E4E1E7"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .tint(Color(hex: "#0A84FF"))
                } else {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#E4E1E7"))
                        .tint(Color(hex: "#0A84FF"))
                }

                Button(action: onToggle) {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Preview

    #Preview("Add Playlist – iPhone") {
        AddPlaylistView_iOS(
            store: Store(initialState: AddPlaylistFeature.State()) {
                AddPlaylistFeature()
            }
        )
    }

    #Preview("Add Playlist – Error State") {
        AddPlaylistView_iOS(
            store: Store(
                initialState: {
                    var s = AddPlaylistFeature.State()
                    s.errorMessage = String(localized: "Kullanıcı adı veya şifre hatalı.")
                    s.serverURL = "http://example.com:8080"
                    s.username = "user"
                    s.password = "wrong"
                    return s
                }()
            ) {
                AddPlaylistFeature()
            }
        )
    }
#endif
