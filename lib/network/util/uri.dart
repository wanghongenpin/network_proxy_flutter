import 'dart:collection';

/// Uri构建工具类
class UriBuild {
  /// 构建Uri
  static Uri build(String url, {Map<String, dynamic>? params}) {
    var uri = Uri.parse(url);
    if (params == null) {
      return uri;
    }
    var queries = HashMap<String, List<String>>();
    queries.addAll(uri.queryParametersAll);
    params.forEach((key, value) {
      var values = queries[key];
      if (values == null) {
        values = [];
        queries[key] = values;
      }
      values.add(value.toString());
    });

    return uri.replace(queryParameters: queries);
  }
}
