/// @author wanghongen
/// 2023/7/26
class RequestRewrites {
  bool enabled = true;
  final List<RequestRewriteRule> rules = [];

  RequestRewrites._();

  //单例
  static final RequestRewrites _instance = RequestRewrites._();

  static RequestRewrites get instance => _instance;

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

  String? findRequestReplaceWith(String? domain, String? url) {
    if (!enabled || url == null) {
      return null;
    }
    for (var rule in rules) {
      if (rule.enabled && rule.urlReg.hasMatch(url)) {
        if (rule.domain?.isNotEmpty == true && rule.domain != domain) {
          continue;
        }
        return rule.requestBody;
      }
    }
    return null;
  }

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

class RequestRewriteRule {
  bool enabled = false;
  final String path;
  final String? domain;
  final RegExp urlReg;
  String? requestBody;
  String? responseBody;

  RequestRewriteRule(this.enabled, this.path, this.domain, {this.requestBody, this.responseBody})
      : urlReg = RegExp(path.replaceAll("*", ".*"));

  factory RequestRewriteRule.formJson(Map<String, dynamic> map) {
    return RequestRewriteRule(map['enabled'] == true, map['path'] ?? map['url'], map['domain'],
        requestBody: map['requestBody'], responseBody: map['responseBody']);
  }

  toJson() {
    return {
      'enabled': enabled,
      'domain': domain,
      'path': path,
      'requestBody': requestBody,
      'responseBody': responseBody,
    };
  }
}
