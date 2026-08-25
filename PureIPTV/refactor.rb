require 'fileutils'

dir = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Features'
Dir.glob("#{dir}/**/*.swift").each do |file|
  content = File.read(file)
  
  # Replace models
  content.gsub!('XtreamCategoryModel', 'MediaCategory')
  content.gsub!('XtreamChannelModel', 'MediaItem')
  content.gsub!('XtreamVODModel', 'MediaItem')
  content.gsub!('XtreamSeriesModel', 'MediaItem')
  
  # Replace ServerConfig with PlaylistConfig
  content.gsub!('ServerConfig', 'PlaylistConfig')
  
  # Replace onAppear(serverURL: String, username: String, password: String) with onAppear(config: PlaylistConfig)
  content.gsub!(/onAppear\(serverURL: String, username: String, password: String\)/, 'onAppear(config: PlaylistConfig)')
  
  # Replace onAppear(serverURL, username, password) with onAppear(config)
  content.gsub!(/onAppear\(serverURL, username, password\)/, 'onAppear(config)')

  File.write(file, content)
end

app_feature = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Features/App/AppFeature.swift'
content = File.read(app_feature)
content.gsub!('serverURL: serverURL,', 'config: PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)')
content.gsub!(/username: username,\s*password: password/, '')
File.write(app_feature, content)

puts "Done"
