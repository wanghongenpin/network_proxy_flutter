import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract interface class AppLifecycleListener {
  void onUserLeaveHint(AppLifecycleState state);

  void onDetached(AppLifecycleState state);
}

class AppLifecycleBinding {
  static const MethodChannel _methodChannel = MethodChannel('com.proxy/appLifecycle');
  static bool _initialized = false;

  static ensureInitialized() {
    if (_initialized) {
      return;
    }

    //注册方法
    _methodChannel.setMethodCallHandler(_methodCallHandler);
    _initialized = true;
  }

  static Future<void> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'appDetached':
        await WidgetsBinding.instance.handleRequestAppExit();
        break;
      case 'userLeaveHint':
        print("userLeaveHint");
        // WidgetsBinding.instance.handleRequestAppExit();
        break;
    }
    return Future.value();
  }
}
