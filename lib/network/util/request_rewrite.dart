/// @author wanghongen
/// 2023/7/26
/// 请求重写
class RequestRewrites {
  bool enabled = true;
  final List<RequestRewriteRule> rules = [];

  RequestRewrites._();

  //单例
  static final RequestRewrites _instance = RequestRewrites._();

  static RequestRewrites get instance => _instance;

  //加载配置
  load(Map<String, dynamic>? map) {
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
  factory RequestRewriteRule.formJson(Map<String, dynamic> map) {
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
