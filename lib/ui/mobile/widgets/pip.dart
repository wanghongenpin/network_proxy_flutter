import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/native/pip.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/utils/ip.dart';

class PictureInPictureWindow extends StatefulWidget {
  final ProxyServer proxyServer;

  const PictureInPictureWindow(
    this.proxyServer, {
    super.key,
  });

  @override
  State<PictureInPictureWindow> createState() => _PictureInPictureState();
}

class _PictureInPictureState extends State<PictureInPictureWindow> {
  static double xPosition = -1;
  static double yPosition = -1;
  static Size? size;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) return const SizedBox();

    size ??= MediaQuery.sizeOf(context);
    if (size == null || size!.isEmpty) {
      size = null;
      return const SizedBox();
    }

    if (xPosition == -1) {
      xPosition = size!.width * 0.9;
      yPosition = size!.height * 0.35;
    }

    return Stack(children: [
      Positioned(
        top: yPosition,
        left: xPosition,
        child: GestureDetector(
            onPanUpdate: (tapInfo) {
              if (xPosition + tapInfo.delta.dx < 0) return;
              if (yPosition + tapInfo.delta.dy < 0) return;

              setState(() {
                xPosition += tapInfo.delta.dx;
                yPosition += tapInfo.delta.dy;
              });
            },
            child: IconButton(
                tooltip: localizations.windowMode,
                onPressed: () async {
                  PictureInPicture.enterPictureInPictureMode(
                      Platform.isAndroid ? await localIp() : "127.0.0.1", widget.proxyServer.port);
                },
                icon: const Icon(Icons.picture_in_picture))),
      )
    ]);
  }
}
