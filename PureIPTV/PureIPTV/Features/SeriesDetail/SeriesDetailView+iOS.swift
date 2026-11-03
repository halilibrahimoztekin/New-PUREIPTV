#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SeriesDetailView_iOS: View {
        let store: StoreOf<SeriesDetailFeature>
        let onPresentSynopsis: (String) -> Void

        public init(
            store: StoreOf<SeriesDetailFeature>,
            onPresentSynopsis: @escaping (String) -> Void = { _ in }
        ) {
            self.store = store
            self.onPresentSynopsis = onPresentSynopsis
        }

        public var body: some View {
            ZStack(alignment: .top) {
                AppColors.surfaceDark.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            headerView
                            contentView
                        }
                    }
                    .task(id: store.pendingEpisodeReveal?.id) {
                        guard let request = store.pendingEpisodeReveal else { return }
                        await Task.yield()
                        guard !Task.isCancelled,
                              store.pendingEpisodeReveal?.id == request.id,
                              store.selectedSeasonNumber == request.seasonNumber
                        else { return }
                        proxy.scrollTo(request.episodeID, anchor: .center)
                        await Task.yield()
                        guard !Task.isCancelled,
                              store.pendingEpisodeReveal?.id == request.id,
                              store.selectedSeasonNumber == request.seasonNumber
                        else { return }
                        store.send(.episodeRevealHandled(request.id))
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onDisappear {
                store.send(.viewDidDisappear)
            }
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 8) {
                    if store.canManageTMDBMatch {
                        Button { store.send(.showTMDBMatchPicker) } label: {
                            Label(AppStrings.TMDBMatchPicker.title, systemImage: "film")
                                .font(AppFonts.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .liquidGlass(shape: .capsule, isInteractive: true)
                        }
                    }

                    if store.canManagePresentation {
                        Button { store.send(.editPresentationTapped) } label: {
                            Label(AppStrings.MediaPresentation.edit, systemImage: "pencil")
                                .font(AppFonts.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .liquidGlass(shape: .capsule, isInteractive: true)
                        }
                        .disabled(!store.isPresentationOverrideLoaded)
                        .accessibilityHint(AppStrings.MediaPresentation.localOnlyDescription)
                    }
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.closeTapped)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(AppFonts.bodyMedium.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(8)
                            .liquidGlass(shape: .circle, isInteractive: true)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Reload or Sync Action
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(AppFonts.bodyMedium.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(8)
                            .liquidGlass(shape: .circle, isInteractive: true)
                    }
                }
            }
        }

        private var headerView: some View {
            SeriesDetailHeroHeaderView_iOS(store: store)
        }

        private var contentView: some View {
            VStack(alignment: .leading, spacing: 24) {
                // Description
                let plot = store.tmdbTV?.overview ?? store.info?.plot
                if let plotText = plot, !plotText.isEmpty {
                    ExpandableSynopsisView(
                        text: plotText,
                        font: AppFonts.bodyMedium,
                        lineLimit: 5,
                        onPresent: { onPresentSynopsis(plotText) }
                    )
                    .padding(.horizontal, 24)
                } else if store.isTMDBLoading || store.isLoading {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(AppColors.borderMedium).frame(height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(AppColors.borderMedium).frame(height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(AppColors.borderMedium).frame(width: 220, height: 14)
                    }
                    .shimmeringPlaceholder(isLoading: true)
                    .padding(.horizontal, 24)
                }

                if !store.awardRecognitions.isEmpty {
                    AwardRecognitionMetadataView(recognitions: store.awardRecognitions)
                        .padding(.horizontal, 24)
                }

                WatchAvailabilitySection(
                    countryCode: store.watchAvailabilityCountryCode,
                    availability: store.watchAvailability,
                    updatedAt: store.watchAvailabilityLoadedAt,
                    isLoading: store.isWatchAvailabilityLoading,
                    failed: store.watchAvailabilityFailed,
                    onSelectCountry: { store.send(.watchAvailabilityCountrySelected($0)) },
                    onRetry: { store.send(.retryWatchAvailability) }
                )
                .padding(.horizontal, 24)

                // Seasons Header & Picker
                SeriesDetailSeasonPickerView_iOS(store: store)

                // Next Up Episode Auto-Cue Banner
                if let nextEp = store.nextUpEpisode {
                    VStack(alignment: .leading, spacing: 10) {
                        NextUpEpisodeBannerView(
                            episode: nextEp,
                            userAgentOverride: store.config.userAgentOverride,
                            playlistID: store.config.playlistID,
                            seriesTitle: store.series.displayTitle,
                            progressItem: store.episodeProgressMap[nextEp.id],
                            onPlay: {
                                store.send(.playNextEpisodeTapped)
                            }
                        )
                        .padding(.horizontal, 24)
                    }
                }

                if let diagnostics = store.info?.seriesCatalogDiagnostics, !diagnostics.isEmpty {
                    SeriesEpisodeCatalogDiagnosticsView(diagnostics: diagnostics)
                        .padding(.horizontal, 24)
                }

                // Episodes List & Grid Toggle
                SeriesDetailEpisodeListView_iOS(store: store)

                Spacer().frame(height: 40)
            }
        }
    }
#endif
