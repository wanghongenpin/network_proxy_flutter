import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/util/host_filter.dart';
import 'package:network_proxy/ui/desktop/toolbar/launch/launch.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/setting.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/theme.dart';
import 'package:network_proxy/ui/mobile/filter.dart';
import 'package:network_proxy/ui/mobile/ssl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'request.dart';
import 'request_rewrite.dart';

class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return MobileHomeState();
  }
}

class MobileHomeState extends State<MobileHomePage> implements EventListener {
  static const MethodChannel proxyVpnChannel = MethodChannel('com.proxy/proxyVpn');
  final ValueNotifier<bool> sllEnableListenable = ValueNotifier<bool>(true);

  late ProxyServer proxyServer;
  final requestStateKey = GlobalKey<RequestWidgetState>();

  @override
  void onRequest(Channel channel, HttpRequest request) {
    requestStateKey.currentState!.add(channel, request);
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {
    requestStateKey.currentState!.addResponse(channel, response);
  }

  @override
  void initState() {
    proxyServer = ProxyServer(listener: this);
    proxyServer.initialize().then((value) => sllEnableListenable.value = proxyServer.enableSsl);
    super.initState();
  }

  @override
  void dispose() {
    sllEnableListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text("ProxyPin"), actions: [
          IconButton(
              tooltip: "清理",
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () => requestStateKey.currentState?.clean()),
          ValueListenableBuilder(
              valueListenable: sllEnableListenable,
              builder: (_, bool enabled, __) => IconButton(
                  tooltip: "Https代理",
                  icon: Icon(Icons.https, color: enabled ? null : Colors.red),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (BuildContext context) {
                        return MobileSslWidget(
                            proxyServer: proxyServer, onEnableChange: (val) => sllEnableListenable.value = val);
                      }),
                    );
                  }))
        ]),
        drawer: drawer(),
        floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: SocketLaunch(
              proxyServer: proxyServer,
              size: 38,
              onStart: () {
                proxyVpnChannel.invokeMethod("startVpn", {"proxyHost": "127.0.0.1", "proxyPort": proxyServer.port});
              },
              onStop: () {
                proxyVpnChannel.invokeMethod("stopVpn");
              },
            )),
        body: RequestWidget(key: requestStateKey, proxyServer: proxyServer));
  }

  Drawer drawer() {
    return Drawer(
        child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
          child: const Text('设置'),
        ),
        PortWidget(proxyServer: proxyServer),
        const ThemeSetting(),
        ListTile(
            title: const Text("域名白名单"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () => _filter(HostFilter.whitelist)),
        ListTile(
            title: const Text("域名黑名单"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () => _filter(HostFilter.blacklist)),
        ListTile(title: const Text("请求重写"), trailing: const Icon(Icons.arrow_right), onTap: () => _reqeustRewrite()),
        ListTile(
            title: const Text("Github"),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              launchUrl(Uri.parse("https://github.com/wanghongenpin/network_proxy_flutter"),
                  mode: LaunchMode.externalApplication);
            })
      ],
    ));
  }

  void _filter(HostList hostList) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (BuildContext context) {
        return MobileFilterWidget(proxyServer: proxyServer, hostList: hostList);
      }),
    );
  }

  void _reqeustRewrite() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (BuildContext context) {
        return MobileRequestRewrite(proxyServer: proxyServer);
      }),
    );
  }
}
