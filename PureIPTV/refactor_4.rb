require 'fileutils'

file = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Features/SeriesDetail/SeriesDetailFeature.swift'
content = File.read(file)

content.gsub!('public var seasons: [XtreamSeasonDTO] = []', 'public var seasons: [MediaSeason] = []')
content.gsub!('public var allEpisodes: [String: [XtreamEpisodeModel]] = [:]', 'public var allEpisodes: [String: [MediaEpisode]] = [:]')
content.gsub!('public var info: XtreamSeriesInfoDataDTO?', 'public var info: MediaDetailInfo?')
content.gsub!('public var currentEpisodes: [XtreamEpisodeModel]', 'public var currentEpisodes: [MediaEpisode]')
content.gsub!('infoResponse(Result<XtreamSeriesInfoDTO, Error>)', 'infoResponse(Result<(info: MediaDetailInfo, seasons: [MediaSeason], episodes: [MediaEpisode]), Error>)')
content.gsub!(/case let \.infoResponse\(\.success\(dto\)\):.*?(?=\s*case let \.tmdbSearchResponse)/m, 
<<~EOS
            case let .infoResponse(.success(result)):
                state.info = result.info
                state.seasons = result.seasons
                
                var parsedEpisodes: [String: [MediaEpisode]] = [:]
                for ep in result.episodes {
                    let seasonStr = String(ep.season)
                    parsedEpisodes[seasonStr, default: []].append(ep)
                }
                
                // Sort episodes
                for (key, eps) in parsedEpisodes {
                    parsedEpisodes[key] = eps.sorted { $0.episodeNum < $1.episodeNum }
                }
                state.allEpisodes = parsedEpisodes
                
                state.isLoading = false // Show episodes immediately

                // Fetch TMDB Info
                let searchTitle = state.series.title.cleanedForTMDBSearch()
                print("TMDB search fallback for Series: \\(state.series.title) -> cleaned: \\(searchTitle)")

                let tmdbEffect: Effect<Action> = .run { send in
                    await send(.tmdbSearchResponse(
                        Result { try await tmdbClient.searchTV(searchTitle) }
                    ))
                }

                let timeoutEffect: Effect<Action> = .run { send in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    await send(.tmdbTimeout)
                }

                // Auto-select first season
                if let firstSeason = state.seasons.first {
                    state.selectedSeasonNumber = firstSeason.seasonNumber
                } else if let firstKey = state.allEpisodes.keys.sorted(by: { Int($0) ?? 0 < Int($1) ?? 0 }).first {
                    state.selectedSeasonNumber = Int(firstKey)
                }

                return .merge(tmdbEffect, timeoutEffect)

EOS
)

content.gsub!(/case let \.episodeSelected\(episode\):.*?return \.none/m,
<<~EOS
            case let .episodeSelected(episode):
                if let streamURL = episode.streamURL {
                    let playable = PlayerFeature.PlayableItem(
                        id: episode.id,
                        title: "\\(state.series.title) - S\\(String(format: "%02d", episode.season))E\\(String(format: "%02d", episode.episodeNum))",
                        streamURL: streamURL
                    )
                    return .send(.delegate(.didSelectEpisode(playable)))
                }
                return .none
EOS
)

content.gsub!('case episodeSelected(XtreamEpisodeModel)', 'case episodeSelected(MediaEpisode)')
content.gsub!('guard let url = URL(string: state.serverURL) else { return .none }\n                let config = PlaylistConfig(baseURL: url, username: state.username, password: state.password)', 'guard let url = URL(string: state.serverURL) else { return .none }\n                let config = PlaylistConfig(type: .xtream, serverURL: url, username: state.username, password: state.password)')

File.write(file, content)

view_file = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Features/SeriesDetail/SeriesDetailView+iOS.swift'
view_content = File.read(view_file)
view_content.gsub!('store.series.plot', 'store.info?.plot')
view_content.gsub!('store.series.coverURL', 'store.series.coverURL')
File.write(view_file, view_content)

puts "Fixed SeriesDetailFeature"
