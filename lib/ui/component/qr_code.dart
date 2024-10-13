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
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:image_pickers/image_pickers.dart';
import 'package:network_proxy/ui/component/state_component.dart';
import 'package:network_proxy/utils/platform.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:zxing_scanner/zxing_scanner.dart';
import 'package:zxing_widget/qrcode.dart';

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
  TextEditingController decodeData = TextEditingController();
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
    decodeData.dispose();
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
          children: [_QrEncode(windowId: widget.windowId), KeepAliveWrapper(child: qrCodeDecode())],
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
                if (path == null) return;

                var result = await scanImage(await File(path).readAsBytes());
                if (result == null || result.isEmpty) {
                  if (mounted) FlutterToastr.show(localizations.decodeFail, context, duration: 2);
                  return;
                }
                decodeData.text = result[0].text;
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
                  decodeData.text = scanRes;
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
      Container(
          padding: const EdgeInsets.all(10),
          height: 300,
          child: Column(children: [
            TextField(
              controller: decodeData,
              maxLines: 7,
              minLines: 7,
              readOnly: true,
              decoration: _decoration(context, localizations.encodeResult),
            ),
            SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                if (decodeData.text.isEmpty) return;
                Clipboard.setData(ClipboardData(text: decodeData.text));
                FlutterToastr.show(localizations.copied, context);
              },
              label: Text(localizations.copy),
            ),
          ])),
      SizedBox(height: 10),
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
      String? file = await DesktopMultiWindow.invokeMethod(0, 'pickFile', <String>['jpg', 'png', 'jpeg']);
      if (widget.windowId != null) WindowController.fromWindowId(widget.windowId!).show();
      return file;
    }

    return null;
  }
}

InputDecoration _decoration(BuildContext context, String label, {String? hintText}) {
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

class _QrEncode extends StatefulWidget {
  final int? windowId;

  const _QrEncode({this.windowId});

  @override
  State<StatefulWidget> createState() => _QrEncodeState();
}

//生成二维码
class _QrEncodeState extends State<_QrEncode> with AutomaticKeepAliveClientMixin {
  var errorCorrectLevel = ErrorCorrectionLevel.M;
  String? data;
  TextEditingController inputData = TextEditingController();

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void dispose() {
    inputData.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListView(children: [
      Container(
          padding: const EdgeInsets.all(10),
          height: 160,
          child: TextField(
              controller: inputData,
              maxLines: 8,
              onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: _decoration(context, localizations.inputContent))),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 10),
          Row(children: [
            Text("${localizations.errorCorrectLevel}: "),
            DropdownButton<ErrorCorrectionLevel>(
                value: errorCorrectLevel,
                items: ErrorCorrectionLevel.values
                    .map((e) =>
                        DropdownMenuItem<ErrorCorrectionLevel>(value: e, child: Text(getErrorCorrectLevelName(e))))
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
                  data = inputData.text;
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
      if (data != null)
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
            Center(
                child: BarcodeWidget(
                    size: const Size(300, 300),
                    QrcodePainter(inputData.text, errorCorrectionLevel: errorCorrectLevel))),
          ],
        ),
      SizedBox(height: 15),
    ]);
  }

  //保存相册
  saveImage() async {
    if (data == null) {
      return;
    }

    if (Platforms.isMobile()) {
      var imageBytes = await toImageBytes(data!);
      String? path = await ImagePickers.saveByteDataImageToGallery(imageBytes);
      if (path != null && mounted) {
        FlutterToastr.show(localizations.saveSuccess, context, duration: 2, rootNavigator: true);
      }
      return;
    }

    if (Platforms.isDesktop()) {
      String? path = await DesktopMultiWindow.invokeMethod(0, 'saveFile', "qrcode.png");
      if (widget.windowId != null) WindowController.fromWindowId(widget.windowId!).show();
      if (path == null) return;

      var imageBytes = await toImageBytes(data!);
      await File(path).writeAsBytes(imageBytes);
      if (mounted) {
        FlutterToastr.show(localizations.saveSuccess, context, duration: 2);
      }
    }
  }

  Future<Uint8List> toImageBytes(String data) async {
    QrcodePainter painter = QrcodePainter(data, errorCorrectionLevel: errorCorrectLevel);
    ui.Image image = (await painter.toImage(ui.Size(300, 300)));
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  static String getErrorCorrectLevelName(ErrorCorrectionLevel level) {
    switch (level) {
      case ErrorCorrectionLevel.L:
        return 'Low';
      case ErrorCorrectionLevel.M:
        return 'Medium';
      case ErrorCorrectionLevel.Q:
        return 'Quartile';
      case ErrorCorrectionLevel.H:
        return 'High';
      default:
        throw ArgumentError('level $level not supported');
    }
  }
}
