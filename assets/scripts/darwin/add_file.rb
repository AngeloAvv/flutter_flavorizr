require 'xcodeproj'

if ARGV.length < 2 || ARGV.length > 3
  puts 'Wrong number of arguments arguments'
  exit
end

project_path = ARGV[0]
file_path = ARGV[1]
group_name = ARGV.length == 3 ? ARGV[2] : nil

project = Xcodeproj::Project.open(project_path)
group = group_name.nil? ? project.main_group : project.groups.detect { |group| group.name == group_name }

file = group.find_file_by_path(file_path)
if file.nil?
  file = group.new_reference(ARGV[1])
  project.targets[0].resources_build_phase.add_file_reference(file)
  project.save
end
