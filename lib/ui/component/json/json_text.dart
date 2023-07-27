import 'package:flutter/material.dart';
import 'package:network_proxy/ui/component/json/theme.dart';

class JsonText extends StatelessWidget {
  final ColorTheme colorTheme;

  final dynamic json;
  final String indent;

  const JsonText({super.key, required this.json, this.indent = '  ', required this.colorTheme});

  @override
  Widget build(BuildContext context) {
    TextSpan jsonText;
    if (json is Map) {
      jsonText = TextSpan(children: getMapText(json, prefix: indent));
    } else if (json is List) {
      jsonText = TextSpan(children: getArrayText(json));
    } else {
      jsonText = TextSpan(text: json.toString());
    }

    return SelectionArea(child: Text.rich(jsonText));
  }

  /// 获取Map json
  List<InlineSpan> getMapText(Map<String, dynamic> map,
      {String openPrefix = '', String prefix = '', String suffix = ''}) {
    var result = <InlineSpan>[];
    result.add(TextSpan(text: '$openPrefix{\n'));

    var entries = map.entries;
    for (int i = 0; i < entries.length; i++) {
      var entry = entries.elementAt(i);
      String postfix = '${i == entries.length - 1 ? '' : ','} \n';

      var textSpan = TextSpan(text: prefix, children: [
        TextSpan(text: '"${entry.key}"', style: TextStyle(color: colorTheme.propertyKey)),
        const TextSpan(text: ': '),
        getBasicValue(entry.value, postfix),
      ]);
      result.add(textSpan);

      if (entry.value is Map<String, dynamic>) {
        result.add(
            TextSpan(children: getMapText(entry.value, openPrefix: prefix, prefix: '$prefix$indent', suffix: postfix)));
      } else if (entry.value is List) {
        result.add(TextSpan(
            children: getArrayText(entry.value, openPrefix: prefix, prefix: '$prefix$indent', suffix: postfix)));
      }
    }

    result.add(TextSpan(text: '$openPrefix}$suffix'));
    return result;
  }

  /// 获取数组json
  List<InlineSpan> getArrayText(List<dynamic> list, {String openPrefix = '', String prefix = '', String suffix = ''}) {
    var result = <InlineSpan>[];
    result.add(TextSpan(text: '$openPrefix[\n'));

    for (int i = 0; i < list.length; i++) {
      var value = list[i];
      String postfix = '${i == list.length - 1 ? '' : ','} \n';

      result.add(getBasicValue(value, postfix));

      if (value is Map<String, dynamic>) {
        result
            .add(TextSpan(children: getMapText(value, openPrefix: prefix, prefix: '$prefix$indent', suffix: postfix)));
      } else if (value is List) {
        result.add(
            TextSpan(children: getArrayText(value, openPrefix: prefix, prefix: '$prefix$indent', suffix: postfix)));
      }
    }

    result.add(TextSpan(text: '$openPrefix]$suffix'));
    return result;
  }

  /// 获取基本类型值 复杂类型会忽略
  InlineSpan getBasicValue(dynamic value, String suffix) {
    if (value == null) {
      return TextSpan(
          children: [TextSpan(text: 'null', style: TextStyle(color: colorTheme.keyword)), TextSpan(text: suffix)]);
    }

    if (value is String) {
      return TextSpan(
          children: [TextSpan(text: '"$value"', style: TextStyle(color: colorTheme.string)), TextSpan(text: suffix)]);
    }

    if (value is num) {
      return TextSpan(children: [
        TextSpan(text: value.toString(), style: TextStyle(color: colorTheme.number)),
        TextSpan(text: suffix)
      ]);
    }

    if (value is bool) {
      return TextSpan(children: [
        TextSpan(text: value.toString(), style: TextStyle(color: colorTheme.keyword)),
        TextSpan(text: suffix)
      ]);
    }

    return const TextSpan(text: '');
  }
}
