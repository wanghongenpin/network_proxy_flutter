import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/ui/configuration.dart';
import 'package:window_manager/window_manager.dart';

/// 监听窗口变化
class WindowChangeListener extends WindowListener {
  final AppConfiguration appConfiguration;

  WindowChangeListener(this.appConfiguration);

  @override
  void onWindowResized() async {
    final windowSize = await windowManager.getSize();
    logger.d("windowSize: $windowSize");
    appConfiguration.windowSize = windowSize;
    appConfiguration.flushConfig();
  }

  @override
  void onWindowMoved() async {
    final windowPosition = await windowManager.getPosition();
    logger.d("windowPosition: $windowPosition");
    appConfiguration.windowPosition = windowPosition;
    appConfiguration.flushConfig();
  }
}
