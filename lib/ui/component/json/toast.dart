import 'package:flutter/cupertino.dart';
import 'package:flutter_toastr/flutter_toastr.dart';

class Toast {
  static void show(String message, BuildContext context) {
    FlutterToastr.show(message, context);
  }
}
