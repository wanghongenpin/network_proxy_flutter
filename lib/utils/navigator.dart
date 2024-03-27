import 'package:flutter/material.dart';

class NavigatorHelper {
  //私有构造方法
  NavigatorHelper._internal();

  factory NavigatorHelper() {
    return _instance;
  }

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  BuildContext get context =>
      NavigatorHelper().navigatorKey.currentState!.context;

  static final NavigatorHelper _instance = NavigatorHelper._internal();

  //保存单例
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  //返回上一页
  static void pop<T extends Object?>([T? result]) {
    Navigator.of(NavigatorHelper().context).pop<T>(result);
  }

  //跳转到指定页面
  static Future<T?> push<T extends Object?>(Route<T> route) {
    return Navigator.of(NavigatorHelper().context).push(route);
  }

  //返回上一页
  static Future<bool> maybePop<T extends Object?>( [ T? result ]) {
    return Navigator.of(NavigatorHelper().context).maybePop<T>(result);
  }
}

///定义全局的NavigatorHelper对象，页面引入该文件后可以直接使用
NavigatorHelper navigatorHelper = NavigatorHelper();
