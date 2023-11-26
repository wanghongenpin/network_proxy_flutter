import 'dart:convert';
import 'dart:io';

import 'package:network_proxy/network/util/file_read.dart';
import 'package:network_proxy/network/util/logger.dart';

/// @author wanghongen
/// 2023/7/26
/// 请求重写
class RequestRewrites {
  bool enabled = true;
  List<RequestRewriteRule> rules = [];

  //单例
  static RequestRewrites? _instance;

  static Future<RequestRewrites> get instance async {
    if (_instance == null) {
      var config = await _loadRequestRewriteConfig();
      _instance = RequestRewrites.fromJson(config);
    }
    return _instance!;
  }

  //加载配置
  RequestRewrites.fromJson(Map<String, dynamic>? map) {
    reload(map);
  }

  //重新加载配置
  reload(Map<String, dynamic>? map) {
    if (map == null) {
      return;
    }

    enabled = map['enabled'] == true;
    List? list = map['rules'];
    rules.clear();
    list?.forEach((element) {
      rules.add(RequestRewriteRule.formJson(element));
    });
  }

  ///重新加载请求重写
  Future<void> reloadRequestRewrite() async {
    var config = await _loadRequestRewriteConfig();
    reload(config);
  }

  /// 加载请求重写配置文件
  static Future<Map<String, dynamic>?> _loadRequestRewriteConfig() async {
    var home = await FileRead.homeDir();
    var file = File('${home.path}${Platform.pathSeparator}request_rewrite.json');
    var exits = await file.exists();
    if (!exits) {
      return null;
    }

    Map<String, dynamic> config = jsonDecode(await file.readAsString());
    logger.i('加载请求重写配置文件 [$file]');
    return config;
  }

  /// 查找重写规则
  RequestRewriteRule? findRequestRewrite(String? url, RuleType type) {
    if (!enabled || url == null) {
      return null;
    }

    for (var rule in rules) {
      if (rule.enabled && rule.urlReg.hasMatch(url) && type == rule.type) {
        return rule;
      }
    }
    return null;
  }

  /// 查找重写规则
  String? findResponseReplaceWith(String? url) {
    if (!enabled || url == null) {
      return null;
    }

    for (var rule in rules) {
      if (rule.enabled && rule.urlReg.hasMatch(url) && rule.type == RuleType.body) {
        return rule.responseBody;
      }
    }
    return null;
  }

  ///添加规则
  void addRule(RequestRewriteRule rule) {
    rules.removeWhere((it) => it.url == rule.url);
    rules.add(rule);
  }

  removeIndex(List<int> indexes) {
    for (var i in indexes) {
      rules.removeAt(i);
    }
  }

  toJson() {
    return {
      'enabled': enabled,
      'rules': rules.map((e) => e.toJson()).toList(),
    };
  }

  /// 保存请求重写配置文件
  Future<void> flushRequestRewriteConfig() async {
    var home = await FileRead.homeDir();
    var file = File('${home.path}${Platform.pathSeparator}request_rewrite.json');
    bool exists = await file.exists();
    if (!exists) {
      await file.create(recursive: true);
    }
    var json = jsonEncode(toJson());
    logger.i('刷新请求重写配置文件 ${file.path}');
    await file.writeAsString(json);
  }
}

enum RuleType {
  body("重写消息体"),
  // header("重写Header"),
  redirect("重定向");

  //名称
  final String name;

  const RuleType(this.name);

  static RuleType fromName(String name) {
    return values.firstWhere((element) => element.name == name);
  }
}

class RequestRewriteRule {
  bool enabled = false;
  RuleType type;

  String? name;
  String url;

  //消息体
  String? queryParam;
  String? requestBody;
  String? responseBody;

  //重定向
  String? redirectUrl;

  RegExp urlReg;

  RequestRewriteRule(this.enabled,
      {this.name,
      required this.url,
      this.type = RuleType.body,
      this.queryParam,
      this.requestBody,
      this.responseBody,
      this.redirectUrl})
      : urlReg = RegExp(url.replaceAll("*", ".*"));

  /// 从json中创建
  factory RequestRewriteRule.formJson(Map<dynamic, dynamic> map) {
    return RequestRewriteRule(map['enabled'] == true,
        name: map['name'],
        url: map['url'] ?? map['domain'] + map['path'],
        type: map['type'] == null ? RuleType.body : RuleType.fromName(map['type']),
        queryParam: map['queryParam'],
        requestBody: map['requestBody'],
        responseBody: map['responseBody'],
        redirectUrl: map['redirectUrl']);
  }

  void updatePathReg() {
    urlReg = RegExp(url.replaceAll("*", ".*"));
  }

  toJson() {
    return {
      'name': name,
      'enabled': enabled,
      'url': url,
      'type': type.name,
      'queryParam': queryParam,
      'requestBody': requestBody,
      'responseBody': responseBody,
      'redirectUrl': redirectUrl,
    };
  }
}
