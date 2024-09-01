/*
 * Copyright 2023 WangHongEn
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'package:flutter/material.dart';
import 'package:network_proxy/ui/desktop/request/model/search_model.dart';
import 'package:network_proxy/ui/desktop/request/search_condition.dart';

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
