/*
 * Copyright 2024 Hongen Wang All rights reserved.
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

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

///证书哈希名称查看
///@author Hongen Wang
class CertHashWidget extends StatefulWidget {
  const CertHashWidget({super.key});

  @override
  State<StatefulWidget> createState() {
    return _CertHashWidgetState();
  }
}

class _CertHashWidgetState extends State<CertHashWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("系统证书名称", style: TextStyle(fontSize: 16)), centerTitle: true),
        resizeToAvoidBottomInset: false,
        body: ListView(children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            //选择文件
            ElevatedButton.icon(
                onPressed: () async {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['js']);
                  if (result != null) {
                    // File file = File(result.files.single.path!);
                    // String content = await file.readAsString();
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: const Text("File")),
            const SizedBox(width: 15),
            FilledButton.icon(
                onPressed: () async {
                  //失去焦点
                  FocusScope.of(context).requestFocus(FocusNode());
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("Run"))
          ]),
          const SizedBox(width: 10),
          Container(
              padding: const EdgeInsets.all(10),
              height: 320,
              child: TextField(maxLines: 100, decoration: decoration('证书文件内容'))),
          TextButton(onPressed: () {}, child: const Text("Output:", style: TextStyle(fontSize: 16))),
          Expanded(
              child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  height: 150,
                  child: TextField(maxLines: 50, decoration: decoration('安卓系统证书Hash 名称')))),
        ]));
  }

  InputDecoration decoration(String label, {String? hintText}) {
    Color color = Theme.of(context).colorScheme.primary;
    return InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: label,
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        border: OutlineInputBorder(borderSide: BorderSide(width: 0.8, color: color)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(width: 1.5, color: color)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 2, color: color)));
  }
}
