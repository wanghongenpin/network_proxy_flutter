class RequestRewrites {
  bool enabled = true;
  final List<RequestRewriteRule> rules = [];

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

  String? findRequestReplaceWith(String? url) {
    if (!enabled || url == null) {
      return null;
    }
    for (var rule in rules) {
      if (rule.enabled && rule.urlReg.hasMatch(url)) {
        return rule.requestBody;
      }
    }
    return null;
  }

  String? findResponseReplaceWith(String? url) {
    if (!enabled || url == null) {
      return null;
    }
    for (var rule in rules) {
      if (rule.enabled && rule.urlReg.hasMatch(url)) {
        return rule.responseBody;
      }
    }
    return null;
  }

  addRule(RequestRewriteRule rule) {
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
  final String url;
  final RegExp urlReg;
  String? requestBody;
  String? responseBody;

  RequestRewriteRule(this.enabled, this.url, {this.requestBody, this.responseBody})
      : urlReg = RegExp(url.replaceAll("*", ".*"));

  factory RequestRewriteRule.formJson(Map<String, dynamic> map) {
    return RequestRewriteRule(map['enabled'] == true, map['url'],
        requestBody: map['requestBody'], responseBody: map['responseBody']);
  }

  toJson() {
    return {
      'enabled': enabled,
      'url': url,
      'requestBody': requestBody,
      'responseBody': responseBody,
    };
  }
}
