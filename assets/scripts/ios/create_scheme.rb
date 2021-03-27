require 'xcodeproj'

if ARGV.length != 2
  puts 'We need exactly two arguments'
  exit
end

project_path = ARGV[0]
scheme_name = ARGV[1]

project = Xcodeproj::Project.open(project_path)
target = project.targets.first

scheme = Xcodeproj::XCScheme.new
scheme.launch_action.build_configuration = "Debug-#{scheme_name}"
scheme.set_launch_target(target)
scheme.test_action.build_configuration = "Debug-#{scheme_name}"
scheme.profile_action.build_configuration = "Release-#{scheme_name}"
scheme.analyze_action.build_configuration = "Debug-#{scheme_name}"
scheme.archive_action.build_configuration = "Release-#{scheme_name}"
scheme.save_as(project_path, scheme_name)