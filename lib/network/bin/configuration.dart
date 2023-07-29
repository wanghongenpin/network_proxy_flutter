import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:path_provider/path_provider.dart';

class Configuration {
  int port = 9099;

  //是否启用https抓包
  bool enableSsl = false;

  //是否启用桌面抓包
  bool enableDesktop = true;

  //是否引导
  bool guide = false;

  //是否显示更新内容公告
  bool upgradeNotice = true;

  //请求重写
  RequestRewrites requestRewrites = RequestRewrites();

  Configuration._();

  /// 单例
  static Configuration? _instance;

  static Future<Configuration> get instance async {
    if (_instance == null) {
      Configuration configuration = Configuration._();
      await configuration.initConfig();
      _instance = configuration;
    }
    return _instance!;
  }

  /// 初始化配置
  Future<void> initConfig() async {
    // 读取配置文件
    await _loadConfig();
  }

  Future<File> homeDir() async {
    String? userHome;
    if (Platforms.isDesktop()) {
      userHome = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    } else {
      userHome = (await getApplicationSupportDirectory()).path;
    }

    var separator = Platform.pathSeparator;
    return File("${userHome!}$separator.proxypin");
  }

  /// 配置文件
  Future<File> configFile() async {
    var separator = Platform.pathSeparator;
    var home = await homeDir();
    return File("${home.path}${separator}config.cnf");
  }

  /// 刷新配置文件
  flushConfig() async {
    var file = await configFile();
    var exists = await file.exists();
    if (!exists) {
      file = await file.create(recursive: true);
    }
    HostFilter.whitelist.toJson();
    HostFilter.blacklist.toJson();
    var json = jsonEncode(toJson());
    logger.i('刷新配置文件 $runtimeType ${toJson()}');
    file.writeAsString(json);
  }

  /// 加载配置文件
  Future<void> _loadConfig() async {
    var file = await configFile();
    var exits = await file.exists();
    if (!exits) {
      guide = true;
      return;
    }

    Map<String, dynamic> config = jsonDecode(await file.readAsString());
    logger.i('加载配置文件 [$file]');
    port = config['port'] ?? port;
    enableSsl = config['enableSsl'] == true;
    enableDesktop = config['enableDesktop'] ?? true;
    guide = config['guide'] ?? false;
    upgradeNotice = config['upgradeNotice'] ?? true;
    HostFilter.whitelist.load(config['whitelist']);
    HostFilter.blacklist.load(config['blacklist']);

    await _loadRequestRewriteConfig();
  }

  /// 加载请求重写配置文件
  Future<void> _loadRequestRewriteConfig() async {
    var home = await homeDir();
    var file = File('${home.path}${Platform.pathSeparator}request_rewrite.json');
    var exits = await file.exists();
    if (!exits) {
      return;
    }

    Map<String, dynamic> config = jsonDecode(await file.readAsString());

    logger.i('加载请求重写配置文件 [$file]');
    requestRewrites.load(config);
  }

  /// 保存请求重写配置文件
  flushRequestRewriteConfig() async {
    var home = await homeDir();
    var file = File('${home.path}${Platform.pathSeparator}request_rewrite.json');
    bool exists = await file.exists();
    if (!exists) {
      await file.create(recursive: true);
    }
    var json = jsonEncode(requestRewrites.toJson());
    logger.i('刷新请求重写配置文件 ${file.path}');
    file.writeAsString(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'guide': guide,
      'upgradeNotice': upgradeNotice,
      'port': port,
      'enableSsl': enableSsl,
      'enableDesktop': enableDesktop,
      'whitelist': HostFilter.whitelist.toJson(),
      'blacklist': HostFilter.blacklist.toJson(),
    };
  }
}
