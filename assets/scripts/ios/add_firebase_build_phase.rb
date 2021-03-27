require 'xcodeproj'

if ARGV.length != 2
  puts 'We need exactly two arguments'
  exit
end

project_path = ARGV[0]
file_path = ARGV[1]

content = File.read(file_path)

project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.shell_script_build_phases
      .select { |phase| phase.name == 'Firebase Setup' }
      .each { |phase| target.build_phases.delete(phase) }

phase = target.new_shell_script_build_phase('Firebase Setup')
phase.shell_path = '/bin/sh'
phase.shell_script = content
phase.run_only_for_deployment_postprocessing = '0'
phase.simple_attributes.find { |attribute| attribute.plist_name == 'outputPaths' }
     .default_value << '$(SRCROOT)/Runner/GoogleService-Info.plist'

target.build_phases.rotate!(-1)

project.save
