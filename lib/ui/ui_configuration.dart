import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_proxy/main.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:path_provider/path_provider.dart';

///画中画
 ValueNotifier<bool> pictureInPictureNotifier = ValueNotifier(false);

class UIConfiguration {
  ThemeModel theme = ThemeModel();

  UIConfiguration._();

  /// 单例
  static UIConfiguration? _instance;

  static Future<UIConfiguration> get instance async {
    if (_instance == null) {
      UIConfiguration configuration = UIConfiguration._();
      await configuration.initConfig();
      _instance = configuration;
    }
    return _instance!;
  }

  Future<File> get _path async {
    if (Platforms.isDesktop()) {
      var userHome = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      return File('$userHome/.proxypin/ui_config.json');
    }

    final directory = await getApplicationSupportDirectory();
    var file = File('${directory.path}${Platform.pathSeparator}ui_config.json');
    if (!await file.exists()) {
      await file.create();
    }
    return file;
  }

  /// 初始化配置
  Future<void> initConfig() async {
    // 读取配置文件
    var file = await _path;
    print(file);
    var exits = await file.exists();
    if (!exits) {
      return;
    }
    var json = await file.readAsString();
    if (json.isEmpty) {
      return;
    }

    try {
      Map<String, dynamic> config = jsonDecode(json);
      var mode = ThemeMode.values
          .firstWhere((element) => element.name == config['mode'], orElse: () => ThemeMode.system);
      theme = ThemeModel(mode: mode, useMaterial3: config['useMaterial3']);
    } catch (e) {
      print(e);
    }
  }

  /// 刷新配置文件
  flushConfig() async {
    var file = await _path;
    var exists = await file.exists();
    if (!exists) {
      file = await file.create(recursive: true);
    }

    var json = jsonEncode(toJson());
    file.writeAsString(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': theme.mode.name,
      'useMaterial3': theme.useMaterial3,
    };
  }
}
