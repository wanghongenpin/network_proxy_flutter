import 'package:flutter/material.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/desktop/left/model/search_model.dart';
import 'package:network_proxy/ui/desktop/left/search_condition.dart';

class Search extends StatefulWidget {
  final Function(SearchModel searchModel)? onSearch;

  const Search({super.key, this.onSearch});

  @override
  State<StatefulWidget> createState() {
    return _SearchState();
  }
}

class _SearchState extends State<Search> {
  SearchModel searchModel = SearchModel();
  bool searched = false;
  TextEditingController keywordController = TextEditingController();
  bool changing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).hoverColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        cursorHeight: 22,
        controller: keywordController,
        onChanged: (val) async {
          searchModel.keyword = val;

          if (!changing) {
            changing = true;
            Future.delayed(const Duration(milliseconds: 500), () {
              changing = false;
              if (!searched) {
                searchModel.searchOptions = {Option.url, Option.method, Option.responseContentType};
              }
              widget.onSearch?.call(searchModel);
            });
          }
        },
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(0),
          border: InputBorder.none,
          prefixIcon: InkWell(
              child: Icon(Icons.search, color: searched ? Colors.green : Colors.blue),
              onTapDown: (details) {
                searchDialog(details);
              }),
          hintText: 'Search',
          suffixIcon: ContentTypeSelect(onSelected: (contentType) {
            searchModel.responseContentType = contentType;
            widget.onSearch?.call(searchModel);
          }),
        ),
      ),
    );
  }

  searchDialog(TapDownDetails details) {
    if (!searched) {
      searchModel.searchOptions = {Option.url};
    }
    var height = MediaQuery.of(context).size.height;
    showMenu(context: context, position: RelativeRect.fromLTRB(10, height - 410, 10, height - 410), items: [
      PopupMenuItem(
          padding: const EdgeInsets.only(left: 15, right: 15, top: 10),
          enabled: false,
          child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
              child: SizedBox(
                  width: 500,
                  height: 350,
                  child: SearchConditions(
                      searchModel: searchModel,
                      onSearch: (val) {
                        setState(() {
                          searchModel = val;
                          searched = searchModel.isNotEmpty;
                          keywordController.text = searchModel.keyword ?? '';
                          widget.onSearch?.call(searchModel);
                        });
                      }))))
    ]);
  }
}

class ContentTypeSelect extends StatefulWidget {
  final Function(ContentType? contentType) onSelected;

  const ContentTypeSelect({super.key, required this.onSelected});

  @override
  State<StatefulWidget> createState() {
    return ContentTypeState();
  }
}

class ContentTypeState extends State<ContentTypeSelect> {
  String value = "全部";
  List<String> types = ["JSON", "HTML", "JS", "CSS", "TEXT", "IMAGE", "全部"];

  @override
  Widget build(BuildContext context) {
    ContentType.json;
    return PopupMenuButton(
      initialValue: value,
      offset: Offset(-10, (types.length - types.indexOf(value)) * -30.0 - 10),
      tooltip: '响应类型',
      constraints: const BoxConstraints(maxWidth: 75),
      child: Wrap(runAlignment: WrapAlignment.center, children: [
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const Icon(Icons.arrow_drop_up, size: 20)
      ]),
      onSelected: (String value) {
        if (this.value == value) {
          return;
        }
        setState(() {
          this.value = value;
        });
        widget.onSelected(value == "全部" ? null : ContentType.valueOf(value));
      },
      itemBuilder: (BuildContext context) {
        return types.map(item).toList();
      },
    );
  }

  PopupMenuItem<String> item(String value) {
    return PopupMenuItem(
      height: 30,
      value: value,
      child: Text(value, style: const TextStyle(fontSize: 12)),
    );
  }
}
