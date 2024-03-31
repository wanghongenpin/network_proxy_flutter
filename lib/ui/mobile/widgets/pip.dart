import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/native/pip.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/configuration.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:network_proxy/utils/lang.dart';
import 'package:network_proxy/utils/listenable_list.dart';

/// Picture in Picture Window
class PictureInPictureWindow extends StatefulWidget {
  final ListenableList<HttpRequest> container;

  const PictureInPictureWindow(this.container, {super.key});

  @override
  State<PictureInPictureWindow> createState() => _PictureInPictureWindowState();
}

class _PictureInPictureWindowState extends State<PictureInPictureWindow> {
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  OnchangeListEvent<HttpRequest>? changeEvent;

  @override
  void initState() {
    super.initState();
    changeEvent = OnchangeListEvent(() {
      setState(() {});
    });
    widget.container.addListener(changeEvent!);
  }

  @override
  void dispose() {
    widget.container.removeListener(changeEvent!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.container.isEmpty) {
      return Material(child: Center(child: Text(localizations.emptyData, style: const TextStyle(color: Colors.grey))));
    }

    return Material(
        child: ListView.separated(
            padding: const EdgeInsets.only(left: 2),
            itemCount: widget.container.length,
            separatorBuilder: (context, index) => const Divider(thickness: 0.3, height: 0.5),
            itemBuilder: (context, index) {
              return Text.rich(
                  overflow: TextOverflow.ellipsis,
                  TextSpan(
                      text: widget.container.elementAt(widget.container.length - index - 1).requestUrl.fixAutoLines(),
                      style: const TextStyle(fontSize: 9)),
                  maxLines: 2);
            }));
  }
}

/// pip Icon
class PictureInPictureIcon extends StatefulWidget {
  final ProxyServer proxyServer;

  const PictureInPictureIcon(
    this.proxyServer, {
    super.key,
  });

  @override
  State<PictureInPictureIcon> createState() => _PictureInPictureState();
}

class _PictureInPictureState extends State<PictureInPictureIcon> {
  static double xPosition = -1;
  static double yPosition = -1;
  static Size? size;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      AppConfiguration.current?.pipEnabled.addListener(() {
        setState(() {});
      });
    }

    AppConfiguration.current?.pipIcon.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS && AppConfiguration.current?.pipEnabled.value == false) return const SizedBox();
    if (Platform.isAndroid && AppConfiguration.current?.pipIcon.value != true) return const SizedBox();

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
                      Platform.isAndroid ? await localIp() : "127.0.0.1", widget.proxyServer.port,
                      appList: widget.proxyServer.configuration.appWhitelist,
                      disallowApps: widget.proxyServer.configuration.appBlacklist);
                },
                icon: const Icon(Icons.picture_in_picture_alt))),
      )
    ]);
  }
}
