/*
 * Copyright (c) 2024 Angelo Cassano
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:flutter_flavorizr/src/parser/models/flavorizr.dart';
import 'package:flutter_flavorizr/src/processors/commons/abstract_processor.dart';
import 'package:mason_logger/mason_logger.dart';

class DarwinAddBuildConfigurationProcessor extends AbstractProcessor<void> {
  final String projectPath;
  final String xconfigPath;
  final String flavorName;
  final String mode;
  final Map<String, dynamic> buildSettings;

  const DarwinAddBuildConfigurationProcessor(
    this.projectPath,
    this.xconfigPath,
    this.flavorName,
    this.mode,
    this.buildSettings, {
    required Flavorizr config,
    required Logger logger,
  }) : super(config, logger: logger);

  @override
  Future<void> execute() async {
    final project = await XcodeProject.open(projectPath);
    final configName = '$mode-$flavorName';
    final configType = mode.toLowerCase() == 'debug'
        ? BuildConfigType.debug
        : BuildConfigType.release;
    final fileRef = project.files.firstWhere((f) => f.path == xconfigPath);
    final nativeTarget = project.targets.first as PBXNativeTarget;

    final targetConfig = project.newObject<XCBuildConfiguration>(
        (g, u) => XCBuildConfiguration(g, u));
    targetConfig.name = configName;
    targetConfig.buildSettings = {'PRODUCT_NAME': r'$(TARGET_NAME)'};
    targetConfig.baseConfigurationReference = fileRef;
    nativeTarget.buildConfigurationList!.buildConfigurations.add(targetConfig);

    final baseConfig =
        project.buildConfigurations.firstWhere((c) => c.name == mode);
    final projectConfig = project.addBuildConfiguration(configName, configType);
    projectConfig.baseConfigurationReference = fileRef;
    projectConfig.buildSettings = {
      ...Map<String, dynamic>.from(baseConfig.buildSettings),
      ...buildSettings,
    };

    await project.save();
  }

  @override
  String toString() => 'DarwinAddBuildConfigurationProcessor';
}
