require 'xcodeproj'
require 'json'
require 'base64'

if ARGV.length != 6
  puts 'We need exactly six arguments'
  exit
end

project_path = ARGV[0]
file_path = ARGV[1]
flavor = ARGV[2]
# bundleId = ARGV[3]
mode = ARGV[4]
additional_build_settings = JSON.parse(Base64.decode64(ARGV[5]))

project = Xcodeproj::Project.open(project_path)

base_config = project.build_configuration_list.build_configurations.detect { |config| config.name == mode }

build_config = project.add_build_configuration("#{mode}-#{flavor}", mode.downcase == 'debug' ? :debug : :release)
build_config.base_configuration_reference = project.files.detect { |file| file.path == file_path }
build_config.build_settings = base_config.build_settings.clone
build_config.build_settings = build_config.build_settings.merge(additional_build_settings)

# Add other build dummy configurations for targets
project.targets.each do |target|  
    build_configx = target.add_build_configuration("#{mode}-#{flavor}", mode.downcase == 'debug' ? :debug : :release)
    build_configx.build_settings = {
        "PRODUCT_NAME" => target.name,
    }
end
##

project.save