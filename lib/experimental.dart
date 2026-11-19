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

/// **Experimental**: nothing exported here is covered by semver. A symbol may
/// change or go away in any release, until it is promoted to
/// `package:flutter_flavorizr/flutter_flavorizr.dart`.
///
/// It holds what processors are written with:
///
/// * idempotent building blocks: the artifacts a processor tracks and who owns
///   them ([Artifact], [Ownership]), the marked regions of a file
///   ([RegionMarker]), the owned keys of an `Info.plist` ([InfoPlistEditor]),
///   the entries of a `launch.json` ([VsCodeLaunchEditor]), and the Xcode
///   project that processors share ([XcodeprojResource], [OwnedObjects]);
/// * the models of the configuration, which are read-only: a processor reads
///   them through `FlavorizrContext.config`, and cannot change them.
library;

export 'src/badge/badge_color.dart' show BadgeColor;
export 'src/badge/badge_palette.dart' show badgePalette, defaultBadgeColor;
export 'src/badge/badge_source_icon.dart'
    show
        BadgeSourceFiles,
        BadgeSourceIcon,
        BadgeSourceIconException,
        BadgeSourceOrigin,
        minBadgeSourceSize,
        resolveBadgeSourceIcon;
export 'src/badge/resolved_badge.dart' show ResolvedBadge;
export 'src/engine/artifact.dart';
export 'src/engine/darwin/owned_objects.dart' show OwnedObjects, ObjectFactory;
export 'src/engine/ownership.dart' show Ownership;
export 'src/engine/processors/darwin/info_plist_editor.dart'
    show InfoPlistEditor;
export 'src/engine/processors/ide/vscode_launch_editor.dart'
    show VsCodeLaunchEditor;
export 'src/engine/processors/linux/marked_text.dart' show RegionMarker;
export 'src/engine/resources/xcodeproj_resource.dart'
    show XcodeprojResource, XcodeprojOpener, XcodeprojSaver;
export 'src/parser/mixins/build_settings_mixin.dart' show BuildSettingsMixin;
export 'src/parser/models/config/android.dart' show AndroidDefaults;
export 'src/parser/models/config/app.dart' show AppDefaults;
export 'src/parser/models/config/ios.dart' show IOS;
export 'src/parser/models/config/macos.dart' show MacOS;
export 'src/parser/models/enums.dart' show IDE;
export 'src/parser/models/flavorizr.dart' show FlavorizrConfig;
export 'src/parser/models/flavors/android.dart' show Android;
export 'src/parser/models/flavors/android/adaptive_icon.dart' show AdaptiveIcon;
export 'src/parser/models/flavors/android/build_config_field.dart'
    show BuildConfigField;
export 'src/parser/models/flavors/android/res_value.dart' show ResValue;
export 'src/parser/models/flavors/app.dart' show App;
export 'src/parser/models/flavors/badge.dart' show FlavorBadge;
export 'src/parser/models/flavors/commons/dummy_assets_mixin.dart'
    show DummyAssetsMixin;
export 'src/parser/models/flavors/commons/firebase_mixin.dart'
    show FirebaseMixin;
export 'src/parser/models/flavors/commons/icon_mixin.dart' show IconMixin;
export 'src/parser/models/flavors/commons/os.dart' show OS;
export 'src/parser/models/flavors/darwin.dart' show Darwin;
export 'src/parser/models/flavors/darwin/enums.dart' show Target;
export 'src/parser/models/flavors/darwin/include.dart' show Include;
export 'src/parser/models/flavors/darwin/variable.dart' show Variable;
export 'src/parser/models/flavors/flavor.dart' show Flavor;
export 'src/parser/models/flavors/google/firebase/firebase.dart' show Firebase;
export 'src/parser/models/flavors/huawei/agconnect/agconnect.dart'
    show AGConnect;
export 'src/parser/models/flavors/linux.dart' show Linux;
export 'src/parser/models/flavors/windows.dart' show Windows;
