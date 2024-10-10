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
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:easy_permission/easy_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:image_pickers/image_pickers.dart';
import 'package:network_proxy/ui/component/state_component.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:qr/qr.dart';

///二维码
///@author Hongen Wang
class QrCodeWidget extends StatefulWidget {
  final int? windowId;

  const QrCodeWidget({super.key, this.windowId});

  @override
  State<StatefulWidget> createState() {
    return _QrCodeWidgetState();
  }
}

class _QrCodeWidgetState extends State<QrCodeWidget> with SingleTickerProviderStateMixin {
  int errorCorrectLevel = QrErrorCorrectLevel.M;
  String data = "";
  String? decodeData;
  QrCode? qrCode;
  GlobalKey repaintKey = GlobalKey();

  late TabController tabController;
  late List<Tab> tabs = [
    Tab(text: 'Encode'),
    Tab(text: 'Decode'),
  ];

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();

    tabController = TabController(initialIndex: 0, length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    tabs = [
      Tab(text: localizations.encode),
      Tab(text: localizations.decode),
    ];

    return Scaffold(
        appBar: AppBar(
            title: Text(localizations.qrCode, style: TextStyle(fontSize: 16)),
            centerTitle: true,
            bottom: TabBar(tabs: tabs, controller: tabController)),
        resizeToAvoidBottomInset: false,
        body: TabBarView(
          controller: tabController,
          children: [KeepAliveWrapper(child: qrCodeEncode()), KeepAliveWrapper(child: qrCodeDecode())],
        ));
  }

  //qrCode解码
  Widget qrCodeDecode() {
    return ListView(children: [
      SizedBox(height: 15),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 10),
          FilledButton.icon(
              onPressed: () async {
                String? path = await selectImage();
                print(path);
                if (path == null) return;
              },
              icon: const Icon(Icons.photo, size: 18),
              style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
              label: Text(localizations.selectImage)),
          if (Platforms.isMobile())
            FilledButton.icon(
                onPressed: () async {
                  String scanRes;
                  if (Platform.isAndroid) {
                    await EasyPermission.requestPermissions([PermissionType.CAMERA]);
                    scanRes = await scanner.scan() ?? "-1";
                  } else {
                    scanRes =
                        await FlutterBarcodeScanner.scanBarcode("#ff6666", localizations.cancel, true, ScanMode.QR);
                  }

                  if (scanRes == "-1") {
                    if (mounted) FlutterToastr.show(localizations.decodeFail, context, duration: 2);
                    return;
                  }
                  setState(() {
                    decodeData = scanRes;
                  });
                },
                style: ButtonStyle(
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
                label: Text(localizations.scanQrCode, style: TextStyle(fontSize: 14))),
          const SizedBox(width: 20),
        ],
      ),
      const SizedBox(height: 20),
      if (decodeData != null)
        Container(
            padding: const EdgeInsets.all(10),
            height: 300,
            child: Column(children: [
              TextFormField(
                initialValue: decodeData,
                maxLines: 7,
                minLines: 7,
                readOnly: true,
                decoration: decoration(localizations.encodeResult),
              ),
              SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  if (decodeData == null) return;
                  Clipboard.setData(ClipboardData(text: decodeData!));
                  FlutterToastr.show(localizations.copied, context);
                },
                label: Text(localizations.copy),
              ),
            ])),
      SizedBox(height: 10),
    ]);
  }

  //生成二维码
  Widget qrCodeEncode() {
    return ListView(children: [
      Container(
          padding: const EdgeInsets.all(10),
          height: 160,
          child: TextField(
              maxLines: 8,
              onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (value) {
                data = value;
              },
              decoration: decoration(localizations.inputContent))),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 10),
          Row(children: [
            Text("${localizations.errorCorrectLevel}: "),
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
              label: Text(localizations.generateQRcode, style: TextStyle(fontSize: 14))),
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
                  label: Text(localizations.saveImage)),
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

  //选择照片
  Future<String?> selectImage() async {
    if (Platforms.isMobile()) {
      List<Media> listImagePaths = await ImagePickers.pickerPaths(showCamera: true);
      if (listImagePaths.isEmpty) return null;
      return listImagePaths[0].path;
    }

    if (Platforms.isDesktop()) {
      String? file = await DesktopMultiWindow.invokeMethod(0, 'openFile', <String>['jpg', 'png', 'jpeg']);
      WindowController.fromWindowId(widget.windowId!).show();
      return file;
    }

    return null;
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
      String? path = await DesktopMultiWindow.invokeMethod(0, 'getSaveLocation', "qrcode.png");
      WindowController.fromWindowId(widget.windowId!).show();
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
