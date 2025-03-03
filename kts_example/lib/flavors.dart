enum Flavor {
  apple,
  banana,
}

class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? '';

  static String get title {
    switch (appFlavor) {
      case Flavor.apple:
        return 'Apple App';
      case Flavor.banana:
        return 'Banana App';
      default:
        return 'title';
    }
  }

}
