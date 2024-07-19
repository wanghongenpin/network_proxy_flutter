import 'package:network_proxy/ui/configuration.dart';

class Localizations {

  static bool get isEN {
    return AppConfiguration.current?.language?.languageCode == 'en';
  }
}
