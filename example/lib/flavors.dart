enum Flavor {
  APPLE,
  BANANA,
}

extension FlavorName on Flavor {
  String get name => this.toString().split('.').last;
}

class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? '';

  static String get title {
    switch (appFlavor) {
      case Flavor.APPLE:
        return 'Apple App';
      case Flavor.BANANA:
        return 'Banana App';
      default:
        return 'title';
    }
  }
}
