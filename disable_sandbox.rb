require 'xcodeproj'

project_path = 'PureIPTV/PureIPTV.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'PureIPTV' }

target.build_configurations.each do |config|
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

project.save
puts "Disabled User Script Sandboxing for SwiftFormat."
