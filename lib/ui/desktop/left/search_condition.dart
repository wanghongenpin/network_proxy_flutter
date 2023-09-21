import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/desktop/left/model/search_model.dart';
import 'package:network_proxy/utils/lang.dart';

/// @author wanghongen
/// 2023/8/6

class SearchConditions extends StatefulWidget {
  final SearchModel searchModel;
  final Function(SearchModel searchModel)? onSearch;
  final EdgeInsetsGeometry? padding;

  const SearchConditions({super.key, required this.searchModel, this.onSearch, this.padding});

  @override
  State<StatefulWidget> createState() {
    return SearchConditionsState();
  }
}

class SearchConditionsState extends State<SearchConditions> {
  final requestContentMap = {
    'JSON': ContentType.json,
    'FORM-URL': ContentType.formUrl,
    'FORM-DATA': ContentType.formData,
    '全部': null
  };
  final responseContentMap = {
    'JSON': ContentType.json,
    'HTML': ContentType.html,
    'JS': ContentType.js,
    'CSS': ContentType.css,
    'TEXT': ContentType.text,
    'IMAGE': ContentType.image,
    '全部': null
  };

  late SearchModel searchModel;

  @override
  void initState() {
    super.initState();
    searchModel = widget.searchModel.clone();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: searchModel.keyword,
              onChanged: (val) => searchModel.keyword = val,
              decoration: const InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
                hintText: '关键词',
              ),
            ),
            const SizedBox(height: 15),
            const Text("关键词搜索范围:"),
            const SizedBox(height: 10),
            Row(
              children: [
                options('URL', Option.url),
                options('请求头', Option.requestHeader),
                options('请求体', Option.requestBody),
              ],
            ),
            Row(
              children: [options('响应头', Option.responseHeader), options('响应体', Option.responseBody)],
            ),
            const SizedBox(height: 15),
            row(
                const Text('请求方法:'),
                DropdownMenu(
                    initialValue: searchModel.requestMethod?.name ?? '全部',
                    items: HttpMethod.values.map((e) => e.name).toList()..insert(0, '全部'),
                    onSelected: (String value) {
                      searchModel.requestMethod = value == '全部' ? null : HttpMethod.valueOf(value);
                    })),
            const SizedBox(height: 15),
            row(
                const Text('请求类型:'),
                DropdownMenu(
                    initialValue: Maps.getKey(requestContentMap, searchModel.requestContentType) ?? '全部',
                    items: requestContentMap.keys,
                    onSelected: (String value) {
                      searchModel.requestContentType = requestContentMap[value];
                    })),
            const SizedBox(height: 15),
            row(
                const Text('响应类型:'),
                DropdownMenu(
                    initialValue: Maps.getKey(responseContentMap, searchModel.responseContentType) ?? '全部',
                    items: responseContentMap.keys,
                    onSelected: (String value) {
                      searchModel.responseContentType = responseContentMap[value];
                    })),
            row(
              const Text('   状态码:'),
              TextFormField(
                initialValue: searchModel.statusCode?.toString(),
                onChanged: (val) {
                  searchModel.statusCode = int.tryParse(val);
                },
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(5),
                  FilteringTextInputFormatter.allow(RegExp('[-0-9]'))
                ],
                decoration: const InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('取消', style: TextStyle(fontSize: 14))),
                TextButton(
                    onPressed: () {
                      widget.onSearch?.call(SearchModel());
                      Navigator.pop(context);
                    },
                    child: const Text('清除搜索', style: TextStyle(fontSize: 14))),
                TextButton(
                    onPressed: () {
                      widget.onSearch?.call(searchModel);
                      Navigator.pop(context);
                    },
                    child: const Text('确定', style: TextStyle(fontSize: 14))),
              ],
            )
          ],
        ));
  }

  Widget options(String title, Option option) {
    return Row(children: [
      Text(title, style: const TextStyle(fontSize: 12)),
      Checkbox(
          value: searchModel.searchOptions.contains(option),
          onChanged: (val) {
            setState(() {
              val == true ? searchModel.searchOptions.add(option) : searchModel.searchOptions.remove(option);
            });
          })
    ]);
  }

  Widget row(Widget child, Widget child2) {
    return Row(children: [Expanded(flex: 3, child: child), Expanded(flex: 7, child: child2)]);
  }
}

class DropdownMenu<T> extends StatefulWidget {
  final String? initialValue;
  final Iterable<String> items;
  final Function(String value) onSelected;

  const DropdownMenu({super.key, this.initialValue, required this.items, required this.onSelected});

  @override
  State<StatefulWidget> createState() {
    return DropdownMenuState();
  }
}

class DropdownMenuState extends State<DropdownMenu> {
  String? selectValue;

  @override
  void initState() {
    super.initState();
    selectValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      tooltip: '',
      initialValue: selectValue,
      child: Wrap(runAlignment: WrapAlignment.center, children: [
        Text(selectValue ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const Icon(Icons.arrow_drop_down, size: 20)
      ]),
      onSelected: (String value) {
        setState(() {
          widget.onSelected.call(value);
          selectValue = value;
        });
      },
      itemBuilder: (BuildContext context) {
        return widget.items
            .map((it) =>
                PopupMenuItem<String>(height: 35, value: it, child: Text(it, style: const TextStyle(fontSize: 12))))
            .toList();
      },
    );
  }
}
