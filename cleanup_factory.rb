require 'xcodeproj'

project_path = 'PureIPTV/PureIPTV.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'PureIPTV' }

# 1. Remove from PBXFrameworksBuildPhase
frameworks_phase = target.frameworks_build_phase
frameworks_phase.files.delete_if do |file|
  file.product_ref && file.product_ref.display_name && file.product_ref.display_name.include?('Factory')
end

# 2. Remove all Swift Package Product Dependencies containing Factory
target.package_product_dependencies.delete_if do |ref|
  ref.product_name.include?('Factory')
end

# 3. Remove from Root Object Package References
project.root_object.package_references.delete_if do |pkg|
  pkg.repositoryURL && pkg.repositoryURL.include?('Factory')
end

# Remove any XCSwiftPackageProductDependency objects left orphaned
project.objects.select { |obj| obj.isa == 'XCSwiftPackageProductDependency' }.each do |obj|
  if obj.product_name.include?('Factory')
    obj.remove_from_project
  end
end

project.save
puts "Successfully cleaned up Factory references from pbxproj."
