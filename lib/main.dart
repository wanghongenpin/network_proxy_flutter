import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network/network/bin/server.dart';
import 'package:network/ui/left.dart';
import 'package:network/ui/panel.dart';
import 'package:window_manager/window_manager.dart';

import 'network/channel.dart';
import 'network/handler.dart';
import 'network/http/http.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //设置窗口大小
  await windowManager.ensureInitialized();
  WindowOptions windowOptions =
      const WindowOptions(size: Size(1280, 720), center: true, titleBarStyle: TitleBarStyle.hidden);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, ThemeMode currentMode, __) {
          return MaterialApp(
            title: 'ProxyPin',
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: false),
            themeMode: currentMode,
            home: const NetworkHomePage(),
          );
        });
  }
}

class NetworkHomePage extends StatefulWidget {
  const NetworkHomePage({super.key});

  @override
  State<NetworkHomePage> createState() => _NetworkHomePagePageState();
}

class _NetworkHomePagePageState extends State<NetworkHomePage> implements EventListener {
  final NetworkTabController panel = NetworkTabController();
  late DomainWidget domainWidget;
  late ProxyServer proxyServer;

  @override
  void onRequest(Channel channel, HttpRequest request) {
    domainWidget.add(channel, request);
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {
    domainWidget.addResponse(channel, response);
  }

  @override
  void initState() {
    super.initState();
    domainWidget = DomainWidget(panel: panel);
    proxyServer = ProxyServer(listener: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: Tab(
          child: Toolbar(proxyServer, domainWidget),
        ),
        body: Row(children: [
          SizedBox(width: 420, child: domainWidget),
          const Spacer(),
          Expanded(flex: 100, child: domainWidget.panel),
        ]));
  }
}

class Toolbar extends StatefulWidget {
  final ProxyServer proxyServer;
  final DomainWidget domainWidget;

  const Toolbar(this.proxyServer, this.domainWidget, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _ToolbarState();
  }
}

class _ToolbarState extends State<Toolbar> with WindowListener {
  bool started = true;

  @override
  void initState() {
    super.initState();
    widget.proxyServer.start();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    widget.proxyServer.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(padding: EdgeInsets.only(left: Platform.isMacOS ? 80 : 30)),
        IconButton(
            icon: Icon(
              started ? Icons.stop : Icons.play_arrow_sharp,
              color: started ? Colors.red : Colors.green,
              size: 25,
            ),
            onPressed: () async {
              Future<ServerSocket?> result = started ? widget.proxyServer.stop() : widget.proxyServer.start();
              result.then((value) => setState(() {
                    started = !started;
                  }));
            }),
        const Padding(padding: EdgeInsets.only(left: 30)),
        IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () {
              widget.domainWidget.clean();
            }),
        const Padding(padding: EdgeInsets.only(left: 30)),
        IconButton(
            onPressed: () {
              _downloadCert();
            },
            icon: const Icon(Icons.https)),
        const Padding(padding: EdgeInsets.only(left: 30)),
        IconButton(
            onPressed: () {
              MyApp.themeNotifier.value =
                  MyApp.themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            icon: const Icon(Icons.settings)),
      ],
    );
  }

  void _downloadCert() async {
    final String? path = await getSavePath(suggestedName: "ca_root.crt");
    if (path != null) {
      const String fileMimeType = 'application/x-x509-ca-cert';
      var body = await rootBundle.load('assets/certs/ca.crt');
      final XFile xFile = XFile.fromData(
        body.buffer.asUint8List(),
        mimeType: fileMimeType,
      );
      await xFile.saveTo(path);
    }
  }
}
