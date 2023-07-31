import 'package:flutter/material.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/desktop/left/model/search.dart';

class Search extends StatefulWidget {
  final Function(SearchModel searchModel)? onSearch;

  const Search({super.key, this.onSearch});

  @override
  State<StatefulWidget> createState() {
    return _SearchState();
  }
}

class _SearchState extends State<Search> {
  final SearchModel searchModel = SearchModel("", null);
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
        onChanged: (val) async {
          if (searchModel.keyword == val) {
            return;
          }
          searchModel.keyword = val;

          if (!changing) {
            changing = true;
            Future.delayed(const Duration(milliseconds: 500), () {
              changing = false;
              widget.onSearch?.call(searchModel);
            });
          }
        },
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(0),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search',
          suffixIcon: ContentTypeSelect(onSelected: (contentType) {
            if (searchModel.contentType == contentType) {
              return;
            }
            searchModel.contentType = contentType;
            widget.onSearch?.call(searchModel);
          }),
        ),
      ),
    );
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
  List<String> types = ["JSON", "HTML", "JS", "CSS", "IMAGE", 'FONT', "其他", "全部"];

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
        print(value);
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
