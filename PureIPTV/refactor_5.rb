require 'fileutils'

# Fix SeriesDetailView braces
view_file = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Features/SeriesDetail/SeriesDetailView+iOS.swift'
content = File.read(view_file)
content.gsub!(/                        \}\n                    \}\n                \}/, "                    }\n                }")
File.write(view_file, content)

# Add season to MediaEpisode
models_file = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Core/Models/Presentation/MediaDetailInfo.swift'
models = File.read(models_file)
models.gsub!(/public let streamURL: URL\n    public let coverURL: URL\?/, "public let streamURL: URL\n    public let coverURL: URL?\n    public let season: Int")
models.gsub!(/        title: String,\n        streamURL: URL,\n        coverURL: URL\? = nil,/, "        title: String,\n        streamURL: URL,\n        coverURL: URL? = nil,\n        season: Int,")
models.gsub!(/        self\.streamURL = streamURL\n        self\.coverURL = coverURL/, "        self.streamURL = streamURL\n        self.coverURL = coverURL\n        self.season = season")
File.write(models_file, models)

puts "Fixed brace and added season property"
