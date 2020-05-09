require 'xcodeproj'

if ARGV.length != 5
  puts "We need exactly four arguments"
  exit
end

project_path = ARGV[0]
file_path = ARGV[1]
flavor = ARGV[2]
bundleId = ARGV[3]
mode = ARGV[4]


additional_build_settings = {
    "ASSETCATALOG_COMPILER_APPICON_NAME" => "$(ASSET_PREFIX)AppIcon",
    "LD_RUNPATH_SEARCH_PATHS" => "$(inherited) @executable_path/Frameworks",
    "SWIFT_OBJC_BRIDGING_HEADER" => "Runner/Runner-Bridging-Header.h",
    "SWIFT_VERSION" => "5.0",
    "FRAMEWORK_SEARCH_PATHS" => %w[$(inherited) $(PROJECT_DIR)/Flutter],
    "LIBRARY_SEARCH_PATHS" => %w[$(inherited) $(PROJECT_DIR)/Flutter],
    "INFOPLIST_FILE" => "Runner/Info.plist",
    "PRODUCT_BUNDLE_IDENTIFIER" => bundleId,
}

project = Xcodeproj::Project.open(project_path)

base_config = project.build_configuration_list.build_configurations.detect{|config| config.name == mode}

build_config = project.add_build_configuration("#{mode} #{flavor}", mode.downcase == "debug" ? :debug : :release)
build_config.base_configuration_reference = project.files.detect{|file| file.path == file_path}
build_config.build_settings = base_config.build_settings.clone()
build_config.build_settings = build_config.build_settings.merge(additional_build_settings)

project.save