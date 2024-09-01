import 'dart:ui';

import 'package:network_proxy/ui/configuration.dart';

/// @author wanghongen
class Localizations {
  static bool get isZH {
    if (AppConfiguration.current?.language != null) {
      return AppConfiguration.current?.language!.languageCode == 'zh';
    }

    return PlatformDispatcher.instance.locale.languageCode == 'zh';
  }
}
