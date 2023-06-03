import 'flavors.dart';

import 'main.dart' as runner;

Future<void> main() async {
  F.appFlavor = Flavor.[[FLAVOR_NAME]];
  await runner.main();
}
