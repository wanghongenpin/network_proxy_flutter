/*
 * Copyright 2023 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/host_port.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';
import 'package:network_proxy/network/util/system_proxy.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:path_provider/path_provider.dart';

class Configuration {
  ///代理相关配置
  int port = 9099;

  //是否启用https抓包
  bool enableSsl = false;

  //是否设置系统代理
  bool enableSystemProxy = true;

  //代理忽略域名
  String proxyPassDomains = SystemProxy.proxyPassDomains;

  //是否显示更新内容公告
  bool upgradeNoticeV4 = true;

  //请求重写
  RequestRewrites requestRewrites = RequestRewrites.instance;

  //外部代理
  ProxyInfo? externalProxy;

  //白名单应用
  List<String> appWhitelist = [];

  //远程连接 不持久化保存
  String? remoteHost;

  Configuration._();

  /// 单例
  static Configuration? _instance;

  static Future<Configuration> get instance async {
    if (_instance == null) {
      Configuration configuration = Configuration._();
      try {
        await configuration.initConfig();
      } catch (e) {
        logger.e('初始化配置失败', error: e);
      }
      _instance = configuration;
    }
    return _instance!;
  }

  /// 初始化配置
  Future<void> initConfig() async {
    // 读取配置文件
    try {
      await _loadConfig();
    } catch (e) {
      logger.e('加载配置文件失败', error: e);
    }
    await _loadRequestRewriteConfig();
  }

  String? userHome;

  Future<File> homeDir() async {
    if (userHome != null) {
      return File("${userHome!}${Platform.pathSeparator}.proxypin");
    }
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
      return;
    }

    Map<String, dynamic> config = jsonDecode(await file.readAsString());
    logger.i('加载配置文件 [$file]');
    port = config['port'] ?? port;
    enableSsl = config['enableSsl'] == true;
    enableSystemProxy = config['enableSystemProxy'] ?? (config['enableDesktop'] ?? true);
    proxyPassDomains = config['proxyPassDomains'] ?? SystemProxy.proxyPassDomains;
    upgradeNoticeV4 = config['upgradeNoticeV4'] ?? true;
    if (config['externalProxy'] != null) {
      externalProxy = ProxyInfo.fromJson(config['externalProxy']);
    }
    appWhitelist = List<String>.from(config['appWhitelist'] ?? []);
    HostFilter.whitelist.load(config['whitelist']);
    HostFilter.blacklist.load(config['blacklist']);
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
      'upgradeNoticeV4': upgradeNoticeV4,
      'port': port,
      'enableSsl': enableSsl,
      'enableSystemProxy': enableSystemProxy,
      'proxyPassDomains': proxyPassDomains,
      'externalProxy': externalProxy?.toJson(),
      'appWhitelist': appWhitelist,
      'whitelist': HostFilter.whitelist.toJson(),
      'blacklist': HostFilter.blacklist.toJson(),
    };
  }
}
