import 'dart:convert';
import 'dart:io';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/file_read.dart';
import 'package:network_proxy/network/util/logger.dart';
import 'package:network_proxy/utils/lang.dart';

/// @author wanghongen
/// 2023/7/26
/// 请求重写
class RequestRewrites {
  static String separator = Platform.pathSeparator;

  //重写规则
  final Map<RequestRewriteRule, List<RewriteItem>> rewriteItems = {};

  //单例
  static RequestRewrites? _instance;

  RequestRewrites._();

  static Future<RequestRewrites> get instance async {
    if (_instance == null) {
      var config = await _loadRequestRewriteConfig();
      _instance = RequestRewrites._();
      await _instance!.reload(config);
    }
    return _instance!;
  }

  bool enabled = true;
  List<RequestRewriteRule> rules = [];

  //重新加载配置
  Future<void> reload(Map<String, dynamic>? map) async {
    rewriteItems.clear();
    if (map == null) {
      return;
    }

    enabled = map['enabled'] == true;
    List list = map['rules'] ?? [];
    rules.clear();
    bool flush = false;
    for (var element in list) {
      try {
        bool oldVersion = false;
        // body("重写消息体"), 兼容旧版本
        if (element['requestBody']?.isNotEmpty == true || element['queryParam']?.isNotEmpty == true) {
          element['type'] = RuleType.requestReplace.name;

          List<RewriteItem> items = [];
          if (element['requestBody']?.isNotEmpty == true) {
            RewriteItem item = RewriteItem(RewriteType.replaceRequestBody, true);
            item.body = element['requestBody'];
            items.add(item);
          }
          if (element['queryParam']?.isNotEmpty == true) {
            RewriteItem item = RewriteItem(RewriteType.replaceRequestLine, true);
            item.queryParam = element['queryParam'];
            items.add(item);
          }
          var rule = RequestRewriteRule.formJson(element);
          await addRule(rule, items);
          oldVersion = true;
        }

        if (element['responseBody']?.isNotEmpty == true) {
          element['type'] = RuleType.responseReplace.name;
          RewriteItem item = RewriteItem(RewriteType.replaceResponseBody, true);
          item.body = element['responseBody'];
          var rule = RequestRewriteRule.formJson(element);
          await addRule(rule, [item]);

          oldVersion = true;
          continue;
        }

        if (element['redirectUrl']?.isNotEmpty == true) {
          RewriteItem item = RewriteItem(RewriteType.redirect, true);
          item.redirectUrl = element['redirectUrl'];
          var rule = RequestRewriteRule.formJson(element);
          await addRule(rule, [item]);
          oldVersion = true;
          continue;
        }

        if (oldVersion) {
          flush = true;
          continue;
        }
        rules.add(RequestRewriteRule.formJson(element));
      } catch (e) {
        logger.e('加载请求重写配置失败 $element', error: e);
      }
    }

    if (flush) {
      await flushRequestRewriteConfig();
    }
  }

  ///重新加载请求重写
  Future<void> reloadRequestRewrite() async {
    var config = await _loadRequestRewriteConfig();
    reload(config);
  }

  ///同步配置
  Future<void> syncConfig(Map<String, dynamic>? config) async {
    if (config == null) {
      return;
    }

    rewriteItems.clear();
    enabled = config['enabled'] == true;
    List list = config['rules'] ?? [];
    rules.clear();
    for (var element in list) {
      try {
        var rule = RequestRewriteRule.formJson(element);
        List list = element['items'] as List;
        List<RewriteItem> items = list.map((e) => RewriteItem.fromJson(e)).toList();
        await addRule(rule, items);
      } catch (e) {
        logger.e('加载请求重写配置失败 $element', error: e);
      }
    }
    flushRequestRewriteConfig();
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

  ///添加规则
  Future<void> addRule(RequestRewriteRule rule, List<RewriteItem> items) async {
    final home = await FileRead.homeDir();
    String rewritePath = "${separator}rewrite$separator${DateTime.now().millisecondsSinceEpoch}.json";
    var file = File(home.path + rewritePath);
    await file.create(recursive: true);
    file.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
    rule.rewritePath = rewritePath;

    rules.add(rule);
    rewriteItems[rule] = items;
  }

  ///更新规则
  Future<void> updateRule(int index, RequestRewriteRule rule, List<RewriteItem>? items) async {
    rewriteItems.remove(rules[index]);
    final home = await FileRead.homeDir();
    rule._updatePathReg();
    rules[index] = rule;

    if (items == null) {
      return;
    }
    bool isExist = rule.rewritePath != null;
    if (rule.rewritePath == null) {
      String rewritePath = "${separator}rewrite$separator${DateTime.now().millisecondsSinceEpoch}.json";
      rule.rewritePath = rewritePath;
    }

    File file = File(home.path + rule.rewritePath!);
    if (!isExist) {
      await file.create(recursive: true);
    }

    await file.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
    rewriteItems[rule] = items;
  }

  removeIndex(List<int> indexes) async {
    for (var i in indexes) {
      var rule = rules.removeAt(i);
      rewriteItems.remove(rule); //删除缓存
      if (rule.rewritePath != null) {
        File home = await FileRead.homeDir();
        await File(home.path + rule.rewritePath!).delete();
      }
    }
  }

  ///获取重定向
  Future<String?> getRedirectRule(String? url) async {
    var rewriteRule = getRewriteRule(url, RuleType.redirect);
    if (rewriteRule == null) {
      return null;
    }

    var rewriteItems = await getRewriteItems(rewriteRule);
    var redirectUrl = rewriteItems.firstWhereOrNull((element) => element.enabled)?.redirectUrl;
    if (rewriteRule.url.contains("*") && redirectUrl?.contains("*") == true) {
      String ruleUrl = rewriteRule.url.replaceAll("*", "");
      redirectUrl = redirectUrl?.replaceAll("*", url!.replaceAll(ruleUrl, ""));
    }
    return redirectUrl;
  }

  RequestRewriteRule? getRewriteRule(String? url, RuleType type) {
    if (url == null || !enabled) {
      return null;
    }
    for (var rule in rules) {
      if (rule.match(url, type)) {
        return rule;
      }
    }
    return null;
  }

  /// 获取重写规则
  Future<List<RewriteItem>> getRewriteItems(RequestRewriteRule rule) async {
    if (rewriteItems.containsKey(rule)) {
      return rewriteItems[rule]!;
    }
    if (rule.rewritePath == null) {
      return [];
    }

    final home = await FileRead.homeDir();
    List<RewriteItem> items = [];
    try {
      var json = await File(home.path + rule.rewritePath!).readAsString();
      List? list = jsonDecode(json);
      list?.forEach((element) => items.add(RewriteItem.fromJson(element)));
      rewriteItems[rule] = items;
    } catch (e) {
      logger.e('加载请求重写配置文件失败 ${home.path + rule.rewritePath!}', error: e);
    }
    return items;
  }

  /// 查找重写规则
  Future<void> requestRewrite(HttpRequest request) async {
    var url = request.requestUrl;
    var rewriteRule = getRewriteRule(url, RuleType.requestReplace);
    if (rewriteRule == null) {
      return;
    }

    var rewriteItems = await getRewriteItems(rewriteRule);
    rewriteItems.where((item) => item.enabled).forEach((item) => _replaceRequest(request, item));
  }

  //替换请求
  _replaceRequest(HttpRequest request, RewriteItem item) {
    if (item.type == RewriteType.replaceRequestLine) {
      request.method = item.method ?? request.method;
      request.uri = Uri.parse(request.requestUrl).replace(path: item.path, query: item.queryParam).toString();
      return;
    }
    _replaceHttpMessage(request, item);
  }

  /// 查找重写规则
  Future<void> responseRewrite(String? url, HttpResponse response) async {
    var rewriteRule = getRewriteRule(url, RuleType.responseReplace);
    if (rewriteRule == null) {
      return;
    }
    var rewriteItems = await getRewriteItems(rewriteRule);
    rewriteItems.where((item) => item.enabled).forEach((item) => _replaceResponse(response, item));
    logger.d('rewrite response $response');
  }

  //替换相应
  _replaceResponse(HttpResponse response, RewriteItem item) {
    if (item.type == RewriteType.replaceResponseStatus && item.statusCode != null) {
      response.status = HttpStatus.valueOf(item.statusCode!);
      return;
    }
    _replaceHttpMessage(response, item);
  }

  _replaceHttpMessage(HttpMessage message, RewriteItem item) {
    if (item.type == RewriteType.replaceResponseHeader && item.headers != null) {
      item.headers?.forEach((key, value) => message.headers.set(key, value));
      return;
    }

    if (item.type == RewriteType.replaceResponseBody && item.body != null) {
      message.body = item.body?.codeUnits;
      return;
    }
  }

  toJson() {
    return {
      'enabled': enabled,
      'rules': rules.map((e) => e.toJson()).toList(),
    };
  }

  Future<Map<String, dynamic>> toFullJson() async {
    var rulesJson = [];
    for (var rule in rules) {
      var json = rule.toJson();
      json['items'] = await getRewriteItems(rule);
      rulesJson.add(json);
    }

    return {
      'enabled': enabled,
      'rules': rulesJson,
    };
  }
}

enum RuleType {
  // body("重写消息体"), //OLD VERSION

  requestReplace("替换请求"),
  responseReplace("替换响应"),
  // header("重写Header"),
  redirect("重定向");

  //名称
  final String label;

  const RuleType(this.label);

  static RuleType fromName(String name) {
    return values.firstWhere((element) => element.name == name || element.label == name);
  }
}

class RequestRewriteRule {
  bool enabled;
  RuleType type;

  String? name;
  String url;
  RegExp _urlReg;
  String? rewritePath;

  RequestRewriteRule({this.enabled = true, this.name, required this.url, required this.type, this.rewritePath})
      : _urlReg = RegExp(url.replaceAll("*", ".*"));

  bool match(String url, RuleType type) {
    return enabled && this.type == type && _urlReg.hasMatch(url);
  }

  /// 从json中创建
  factory RequestRewriteRule.formJson(Map<dynamic, dynamic> map) {
    return RequestRewriteRule(
        enabled: map['enabled'] == true,
        name: map['name'],
        url: map['url'] ?? map['domain'] + map['path'],
        type: RuleType.fromName(map['type']),
        rewritePath: map['rewritePath']);
  }

  void _updatePathReg() {
    _urlReg = RegExp(url.replaceAll("*", ".*"));
  }

  toJson() {
    return {
      'name': name,
      'enabled': enabled,
      'url': url,
      'type': type.name,
      'rewritePath': rewritePath,
    };
  }
}

class RewriteItem {
  bool enabled;
  final RewriteType type;

  //key redirectUrl, method, path, queryParam, headers, body, statusCode
  final Map<String, dynamic> values = {};

  RewriteItem(this.type, this.enabled, {Map<dynamic, dynamic>? values}) {
    if (values != null) {
      this.values.addAll(Map.from(values));
    }
  }

  factory RewriteItem.fromJson(Map<dynamic, dynamic> map) {
    return RewriteItem(RewriteType.fromName(map['type']), map['enabled'], values: map['values']);
  }

  //redirectUrl
  String? get redirectUrl => values['redirectUrl'];

  set redirectUrl(String? redirectUrl) => values['redirectUrl'] = redirectUrl;

  //method
  HttpMethod? get method => values['method'] == null
      ? null
      : HttpMethod.values.firstWhereOrNull((element) => element.name == values['method']);

  String? get path => values['path'];

  //queryParam
  String? get queryParam => values['queryParam'];

  set queryParam(String? queryParam) => values['queryParam'] = queryParam;

  //statusCode
  int? get statusCode => values['statusCode'];

  set statusCode(int? statusCode) => values['statusCode'] = statusCode;

  //headers
  Map<String, String>? get headers => values['headers'] == null ? null : Map.from(values['headers']);

  set headers(Map<String, String>? headers) => values['headers'] = headers;

  //body
  String? get body => values['body'];

  set body(String? body) => values['body'] = body;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'type': type.name,
      'values': values,
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RewriteType {
  //重定向
  redirect("重定向"),

  //替换请求
  replaceRequestLine("请求行"),
  replaceRequestHeader("请求头"),
  replaceRequestBody("请求体"),
  replaceResponseStatus("状态码"),
  replaceResponseHeader("响应头"),
  replaceResponseBody("响应体"),

  //修改请求
  updateRequestBody("请求体"),
  addQueryParam("添加请求参数"),
  removeQueryParam("删除请求参数"),
  updateQueryParam("修改请求参数"),
  addRequestHeader("添加请求头"),
  removeRequestHeader("删除请求头"),
  updateRequestHeader("修改请求头"),
  updateResponseBody("响应体"),
  updateResponseHeader("响应头"),
  addResponseHeader("添加响应头"),
  removeResponseHeader("删除响应头");

  final String label;

  const RewriteType(this.label);

  static RewriteType fromName(String name) {
    return values.firstWhere((element) => element.name == name);
  }
}
