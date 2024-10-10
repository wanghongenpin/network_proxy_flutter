/*
 * Copyright 2024 Hongen Wang
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
        appBar: AppBar(title: const Text("证书Hash名称", style: TextStyle(fontSize: 16)), centerTitle: true),
        resizeToAvoidBottomInset: false,
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              icon: const Icon(Icons.file_download_sharp),
              label: const Text("File")),
          const SizedBox(width: 15),
          FilledButton.icon(
              onPressed: () async {
                //失去焦点
                FocusScope.of(context).requestFocus(FocusNode());
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("Run")),
          const SizedBox(width: 10),
          SizedBox(
              height: 320,
              child: TextField(
                maxLines: 100,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '证书Hash名称',
                ),
              )),
        ]));
  }
}
