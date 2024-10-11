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
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_permission/easy_permission.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:image_pickers/image_pickers.dart';
import 'package:network_proxy/ui/component/state_component.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:url_launcher/url_launcher.dart';

///二维码
///@author Hongen Wang
class QrCodeWidget extends StatefulWidget {
  const QrCodeWidget({super.key});

  @override
  State<StatefulWidget> createState() {
    return _QrCodeWidgetState();
  }
}

class _QrCodeWidgetState extends State<QrCodeWidget> with SingleTickerProviderStateMixin {
  int errorCorrectLevel = QrErrorCorrectLevel.M;
  String data = "";
  QrCode? qrCode;
  GlobalKey repaintKey = GlobalKey();

  late TabController tabController;
  var tabs = const [
    Tab(text: '编码'),
    Tab(text: '解码'),
  ];

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    tabController = TabController(initialIndex: 0, length: tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text("二维码", style: TextStyle(fontSize: 16)),
            centerTitle: true,
            bottom: TabBar(
              tabs: tabs,
              controller: tabController,
              onTap: (index) {
                setState(() {});
              },
            )),
        resizeToAvoidBottomInset: false,
        body: TabBarView(
          controller: tabController,
          children: [KeepAliveWrapper(child: encode()), KeepAliveWrapper(child: decode())],
        ));
  }

  Widget decode() {
    return ListView(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 10),
          FilledButton.icon(
              onPressed: () async {
                List<Media> _listImagePaths = await ImagePickers.pickerPaths(showCamera: true);
                if (_listImagePaths.isEmpty) return;
                String? path = _listImagePaths[0].path;
                print(path);
                if (path == null) return;
                // QrCode.fromUint8List(data: data, errorCorrectLevel: errorCorrectLevel)
              },
              icon: const Icon(Icons.photo, size: 18),
              style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
              label: Text("选择照片")),
          FilledButton.icon(
              onPressed: () async {
                String scanRes;
                if (Platform.isAndroid) {
                  await EasyPermission.requestPermissions([PermissionType.CAMERA]);
                  scanRes = await scanner.scan() ?? "-1";
                } else {
                  scanRes = await FlutterBarcodeScanner.scanBarcode("#ff6666", localizations.cancel, true, ScanMode.QR);
                }
                if (scanRes == "-1") return;
                if (scanRes.startsWith("http")) {
                  launchUrl(Uri.parse(scanRes), mode: LaunchMode.externalApplication);
                  return;
                }
              },
              style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
              icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
              label: const Text("扫描二维码", style: TextStyle(fontSize: 14))),
          const SizedBox(width: 20),
        ],
      ),
      const SizedBox(height: 10),
      if (qrCode != null)
        Container(
            padding: const EdgeInsets.all(10),
            height: 230,
            child: TextField(
                maxLines: 100,
                onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
                onChanged: (value) {
                  data = value;
                },
                decoration: decoration('二维码内容'))),
      SizedBox(height: 15),
    ]);
  }

  Widget encode() {
    return ListView(children: [
      Container(
          padding: const EdgeInsets.all(10),
          height: 180,
          child: TextField(
              maxLines: 100,
              onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
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
                setState(() {
                  qrCode = QrCode.fromData(data: data, errorCorrectLevel: errorCorrectLevel);
                });
              },
              style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
              icon: const Icon(Icons.qr_code, size: 18),
              label: const Text("生成二维码", style: TextStyle(fontSize: 14))),
          const SizedBox(width: 20),
        ],
      ),
      const SizedBox(height: 10),
      if (qrCode != null)
        Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                  onPressed: () async {
                    await saveImage();
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("保存图片")),
              SizedBox(width: 20),
            ]),
            SizedBox(height: 5),
            RepaintBoundary(
                key: repaintKey,
                child: SizedBox(
                    height: 300,
                    width: 300,
                    child: Center(child: QrImageView.withQr(qr: qrCode!, backgroundColor: Colors.white, size: 300)))),
          ],
        ),
      SizedBox(height: 15),
    ]);
  }

  //保存相册
  saveImage() async {
    if (qrCode == null) {
      return;
    }

    if (Platforms.isMobile()) {
      var imageBytes = await toImageBytes(qrCode!);
      String? path = await ImagePickers.saveByteDataImageToGallery(imageBytes);
      if (path != null && mounted) {
        FlutterToastr.show(localizations.saveSuccess, context, duration: 2, rootNavigator: true);
      }
      return;
    }

    if (Platforms.isDesktop()) {
      String? path = (await getSaveLocation(suggestedName: "qrcode.png"))?.path;
      if (path == null) return;
      var imageBytes = await toImageBytes(qrCode!);
      await File(path).writeAsBytes(imageBytes);
      if (mounted) {
        FlutterToastr.show(localizations.saveSuccess, context, duration: 2);
      }
    }
  }

  Future<Uint8List> toImageBytes(QrCode qrCode) async {
    RenderRepaintBoundary? boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return Uint8List(0);
    }
    ui.Image image = (await boundary.toImage());
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
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
