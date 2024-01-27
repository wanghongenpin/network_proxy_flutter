import 'package:flutter/material.dart';
import 'package:network_proxy/ui/desktop/left/model/search_model.dart';
import 'package:network_proxy/ui/desktop/left/search_condition.dart';

class MobileSearch extends StatefulWidget {
  final Function(SearchModel searchModel)? onSearch;
  final bool showSearch;

  const MobileSearch({super.key, this.onSearch, this.showSearch = false});

  @override
  State<StatefulWidget> createState() {
    return MobileSearchState();
  }
}

class MobileSearchState extends State<MobileSearch> {
  SearchModel searchModel = SearchModel();
  bool searched = false;
  TextEditingController keywordController = TextEditingController();
  bool changing = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showSearch) {
        showSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(left: 20),
        child: TextFormField(
            controller: keywordController,
            cursorHeight: 20,
            keyboardType: TextInputType.url,
            onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (val) {
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
                border: InputBorder.none,
                prefixIcon:
                    InkWell(onTap: showSearch, child: Icon(Icons.search, color: searched ? Colors.green : Colors.blue)),
                hintText: 'Search')));
  }

  showSearch() {
    showModalBottomSheet(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
        isScrollControlled: true,
        context: context,
        builder: (context) {
          if (!searched) {
            searchModel.searchOptions = {Option.url};
          }
          return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SizedBox(
                  height: 430,
                  child: SearchConditions(
                    padding: const EdgeInsets.only(left: 15, right: 15, top: 10),
                    searchModel: searchModel,
                    onSearch: (val) {
                      setState(() {
                        searchModel = val;
                        searched = searchModel.isNotEmpty;
                        keywordController.text = searchModel.keyword ?? '';
                        widget.onSearch?.call(searchModel);
                      });
                    },
                  )));
        });
  }
}
