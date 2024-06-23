import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:path_provider/path_provider.dart';

/// @author wanghongen
/// 2024/1/1
class ThemeModel {
  ThemeMode mode;
  bool useMaterial3;

  ThemeModel({this.mode = ThemeMode.system, this.useMaterial3 = true});

  ThemeModel copy({ThemeMode? mode, bool? useMaterial3}) => ThemeModel(
        mode: mode ?? this.mode,
        useMaterial3: useMaterial3 ?? this.useMaterial3,
      );
}

class AppConfiguration {
  ValueNotifier<bool> globalChange = ValueNotifier(false);

  ThemeModel _theme = ThemeModel();
  Locale? _language;

  //是否显示更新内容公告
  bool upgradeNoticeV10 = true;

  /// 是否启用画中画
  ValueNotifier<bool> pipEnabled = ValueNotifier(true);

  /// 显示画中画图标
  ValueNotifier<bool> pipIcon = ValueNotifier(true);

  /// header默认展示
  bool headerExpanded = true;

  bool? iosVpnBackgroundAudioEnable;

  //桌面window大小
  Size? windowSize;

  //桌面window位置
  Offset? windowPosition;

  AppConfiguration._();

  /// 单例
  static AppConfiguration? _instance;

  static Future<AppConfiguration> get instance async {
    if (_instance == null) {
      AppConfiguration configuration = AppConfiguration._();
      await configuration.initConfig();
      _instance = configuration;
    }
    return _instance!;
  }

  static AppConfiguration? get current => _instance;

  ThemeMode get themeMode => _theme.mode;

  set themeMode(ThemeMode mode) {
    if (mode == _theme.mode) return;
    _theme.mode = mode;
    globalChange.value = !globalChange.value;
    flushConfig();
  }

  ///Material3
  bool get useMaterial3 => _theme.useMaterial3;

  set useMaterial3(bool value) {
    if (value == useMaterial3) return;
    _theme.useMaterial3 = value;
    globalChange.value = !globalChange.value;
    flushConfig();
  }

  ///language
  Locale? get language => _language;

  set language(Locale? locale) {
    if (locale == _language) return;
    _language = locale;
    globalChange.value = !globalChange.value;
    flushConfig();
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
      var mode =
          ThemeMode.values.firstWhere((element) => element.name == config['mode'], orElse: () => ThemeMode.system);
      _theme = ThemeModel(mode: mode, useMaterial3: config['useMaterial3'] ?? true);
      upgradeNoticeV10 = config['upgradeNoticeV10'] ?? true;
      _language = config['language'] == null ? null : Locale.fromSubtags(languageCode: config['language']);
      pipEnabled.value = config['pipEnabled'] ?? true;
      pipIcon.value = config['pipIcon'] ?? false;
      headerExpanded = config['headerExpanded'] ?? true;
      iosVpnBackgroundAudioEnable = config['iosVpnBackgroundAudioEnable'];

      windowSize =
          config['windowSize'] == null ? null : Size(config['windowSize']['width'], config['windowSize']['height']);
      windowPosition = config['windowPosition'] == null
          ? null
          : Offset(config['windowPosition']['dx'], config['windowPosition']['dy']);
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
      'mode': _theme.mode.name,
      'useMaterial3': _theme.useMaterial3,
      'upgradeNoticeV10': upgradeNoticeV10,
      "language": _language?.languageCode,
      'pipEnabled': pipEnabled.value,
      'pipIcon': pipIcon.value ? true : null,
      "headerExpanded": headerExpanded,
      "windowSize": windowSize == null ? null : {"width": windowSize?.width, "height": windowSize?.height},
      "windowPosition": windowPosition == null ? null : {"dx": windowPosition?.dx, "dy": windowPosition?.dy},
      "iosVpnBackgroundAudioEnable": iosVpnBackgroundAudioEnable == false ? null : iosVpnBackgroundAudioEnable
    };
  }
}
