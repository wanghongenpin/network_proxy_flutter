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

import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

///二维码
///@author Hongen Wang
class QrCodeWidget extends StatefulWidget {
  const QrCodeWidget({super.key});

  @override
  State<StatefulWidget> createState() {
    return _QrCodeWidgetState();
  }
}

class _QrCodeWidgetState extends State<QrCodeWidget> {
  int errorCorrectLevel = QrErrorCorrectLevel.M;
  String data = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("二维码", style: TextStyle(fontSize: 16)), centerTitle: true),
        resizeToAvoidBottomInset: false,
        body: ListView(children: [
          Container(
              padding: const EdgeInsets.all(10),
              height: 260,
              child: TextField(
                  maxLines: 100,
                  onChanged: (value) {
                    data = value;
                  },
                  decoration: decoration('文本内容'))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 10),
              Row(children: [
                Text("纠错等级: "),
                DropdownButton<int>(
                    value: errorCorrectLevel,
                    items: QrErrorCorrectLevel.levels
                        .map((e) => DropdownMenuItem<int>(value: e, child: Text(QrErrorCorrectLevel.getName(e))))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        errorCorrectLevel = value!;
                      });
                    }),
              ]),
              const SizedBox(width: 20),
              FilledButton.icon(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ButtonStyle(
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text("生成二维码", style: TextStyle(fontSize: 14))),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 15),
          //右上角显示下载按钮
          Center(child: QrImageView(backgroundColor: Colors.white, data: data, size: 300)),
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
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(width: 1.3, color: color)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 2, color: color)));
  }
}
