import 'package:flutter/material.dart';

abstract interface class AppLifecycleListener {
  void onUserLeaveHint(AppLifecycleState state);
}
