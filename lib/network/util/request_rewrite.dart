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

  ///
  RequestRewriteRule? findRequestRewrite(String? domain, String? url, RuleType type) {
    if (!enabled || url == null) {
      return null;
    }

    for (var rule in rules) {
      if (rule.enabled && rule.urlReg.hasMatch(url) && type == rule.type) {
        if (rule.domain?.isNotEmpty == true && rule.domain != domain) {
          continue;
        }
        return rule;
      }
    }
    return null;
  }

  ///
  String? findResponseReplaceWith(String? domain, String? path) {
    if (!enabled || path == null) {
      return null;
    }
    for (var rule in rules) {
      if (rule.enabled && rule.urlReg.hasMatch(path)) {
        if (rule.domain?.isNotEmpty == true && rule.domain != domain) {
          continue;
        }
        return rule.responseBody;
      }
    }
    return null;
  }

  ///添加规则
  void addRule(RequestRewriteRule rule) {
    rules.removeWhere((it) => it.path == rule.path && it.domain == rule.domain);
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
  String path;
  String? domain;
  RuleType type;

  String? name;

  //消息体
  String? queryParam;
  String? requestBody;
  String? responseBody;

  //重定向
  String? redirectUrl;

  RegExp urlReg;

  RequestRewriteRule(this.enabled, this.path, this.domain,
      {this.name, this.type = RuleType.body, this.queryParam, this.requestBody, this.responseBody, this.redirectUrl})
      : urlReg = RegExp(path.replaceAll("*", ".*"));

  ///
  factory RequestRewriteRule.formJson(Map<String, dynamic> map) {
    return RequestRewriteRule(map['enabled'] == true, map['path'], map['domain'],
        name: map['name'],
        type: map['type'] == null ? RuleType.body : RuleType.fromName(map['type']),
        queryParam: map['queryParam'],
        requestBody: map['requestBody'],
        responseBody: map['responseBody'],
        redirectUrl: map['redirectUrl']);
  }

  void updatePathReg() {
    urlReg = RegExp(path.replaceAll("*", ".*"));
  }

  toJson() {
    return {
      'name': name,
      'enabled': enabled,
      'domain': domain,
      'path': path,
      'type': type.name,
      'queryParam': queryParam,
      'requestBody': requestBody,
      'responseBody': responseBody,
      'redirectUrl': redirectUrl,
    };
  }
}
