path = '/Users/ibrahimoztekin/Desktop/Projeler/New-PureIPTV/PureIPTV/PureIPTV/Features/Player/PlayerView+iOS.swift'
content = File.read(path)
content = content.gsub(/Button\(action: \{ (store\.send\([^}]+)\) \}\)/, 'Button(action: { HapticManager.shared.trigger(.light); \1) })')
content = content.gsub(/Button\(action: \{([^\}]+)\}\)/, 'Button(action: { HapticManager.shared.trigger(.light); \1})')
File.write(path, content)
