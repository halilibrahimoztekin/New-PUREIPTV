require 'fileutils'

dir = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Features'
Dir.glob("#{dir}/**/*.swift").each do |file|
  content = File.read(file)
  
  changed = false
  if content.gsub!(/store\.send\(\.onAppear\(serverURL: serverURL, username: username, password: password\)\)/, 
                   'if let url = URL(string: serverURL) { store.send(.onAppear(config: PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password))) }')
    changed = true
  end

  if content.gsub!(/store\.send\(\.onAppear\(serverURL: store\.serverURL, username: store\.username, password: store\.password\)\)/, 
                   'if let url = URL(string: store.serverURL) { store.send(.onAppear(config: PlaylistConfig(type: .xtream, serverURL: url, username: store.username, password: store.password))) }')
    changed = true
  end

  if content.gsub!(/store\.vod\.posterURL/, 'store.vod.coverURL')
    changed = true
  end
  
  if content.gsub!(/store\.info\?\.movieImage\.flatMap\(URL\.init\)/, 'nil')
    changed = true
  end

  File.write(file, content) if changed
end

puts "Fixed remaining issues"
