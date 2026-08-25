require 'fileutils'

dir = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Features'
Dir.glob("#{dir}/**/*.swift").each do |file|
  content = File.read(file)
  
  changed = false
  
  if content.gsub!(/guard let url = URL\(string: serverURL\) else \{ return \.none \}\n\s*let config = PlaylistConfig\(baseURL: url, username: username, password: password\)\n\s*state\.config = config/, 'state.config = config')
    changed = true
  end

  File.write(file, content) if changed
end

puts "Fixed onAppear config issues"
