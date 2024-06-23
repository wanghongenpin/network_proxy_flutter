import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/native/app_lifecycle.dart';
import 'package:network_proxy/native/pip.dart';
import 'package:network_proxy/native/vpn.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/websocket.dart';
import 'package:network_proxy/network/http_client.dart';
import 'package:network_proxy/ui/configuration.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/launch/launch.dart';
import 'package:network_proxy/ui/mobile/menu/drawer.dart';
import 'package:network_proxy/ui/mobile/menu/menu.dart';
import 'package:network_proxy/ui/mobile/request/list.dart';
import 'package:network_proxy/ui/mobile/request/search.dart';
import 'package:network_proxy/ui/mobile/widgets/connect_remote.dart';
import 'package:network_proxy/ui/mobile/widgets/pip.dart';
import 'package:network_proxy/utils/ip.dart';
import 'package:network_proxy/utils/lang.dart';
import 'package:network_proxy/utils/listenable_list.dart';

class MobileHomePage extends StatefulWidget {
  final Configuration configuration;
  final AppConfiguration appConfiguration;

  const MobileHomePage(this.configuration, this.appConfiguration, {super.key});

  @override
  State<StatefulWidget> createState() {
    return MobileHomeState();
  }
}

class MobileHomeState extends State<MobileHomePage> implements EventListener, LifecycleListener {
  static final GlobalKey<RequestListState> requestStateKey = GlobalKey<RequestListState>();
  static final container = ListenableList<HttpRequest>();

  /// 远程连接
  final ValueNotifier<RemoteModel> desktop = ValueNotifier(RemoteModel(connect: false));

  late ProxyServer proxyServer;

  ///画中画
  // bool pictureInPicture = false;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void onUserLeaveHint() {
    enterPictureInPicture();
  }

  Future<bool> enterPictureInPicture() async {
    if (Vpn.isVpnStarted) {
      if (desktop.value.connect || !Platform.isAndroid || !(await (AppConfiguration.instance)).pipEnabled.value) {
        return false;
      }

      return PictureInPicture.enterPictureInPictureMode(
          Platform.isAndroid ? await localIp() : "127.0.0.1", proxyServer.port,
          appList: proxyServer.configuration.appWhitelist, disallowApps: proxyServer.configuration.appBlacklist);
    }
    return false;
  }

  @override
  onPictureInPictureModeChanged(bool isInPictureInPictureMode) async {
    if (isInPictureInPictureMode) {
      Navigator.push(
          context,
          PageRouteBuilder(
              transitionDuration: Duration.zero,
              pageBuilder: (context, animation, secondaryAnimation) {
                return PictureInPictureWindow(container);
              }));
      return;
    }

    if (!isInPictureInPictureMode) {
      Navigator.maybePop(context);
      Vpn.isRunning().then((value) {
        Vpn.isVpnStarted = value;
        SocketLaunch.startStatus.value = ValueWrap.of(value);
      });
    }
  }

  @override
  void onRequest(Channel channel, HttpRequest request) {
    requestStateKey.currentState!.add(channel, request);
    PictureInPicture.addData(request.requestUrl);
  }

  @override
  void onResponse(ChannelContext channelContext, HttpResponse response) {
    requestStateKey.currentState!.addResponse(channelContext, response);
  }

  @override
  void onMessage(Channel channel, HttpMessage message, WebSocketFrame frame) {
    var panel = NetworkTabController.current;
    if (panel?.request.get() == message || panel?.response.get() == message) {
      panel?.changeState();
    }
  }

  @override
  void initState() {
    super.initState();
    AppLifecycleBinding.instance.addListener(this);
    proxyServer = ProxyServer(widget.configuration);
    proxyServer.addListener(this);
    proxyServer.start();

    //远程连接
    desktop.addListener(() {
      if (desktop.value.connect) {
        proxyServer.configuration.remoteHost = "http://${desktop.value.host}:${desktop.value.port}";
        checkConnectTask(context);
      } else {
        proxyServer.configuration.remoteHost = null;
      }
    });

    if (widget.appConfiguration.upgradeNoticeV10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUpgradeNotice();
      });
    }
  }

  @override
  void dispose() {
    desktop.dispose();
    AppLifecycleBinding.instance.removeListener(this);
    super.dispose();
  }

  int exitTime = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (d) async {
          if (await enterPictureInPicture()) {
            return;
          }

          if (DateTime.now().millisecondsSinceEpoch - exitTime > 2000) {
            exitTime = DateTime.now().millisecondsSinceEpoch;
            if (mounted) {
              FlutterToastr.show(localizations.appExitTips, this.context,
                  rootNavigator: true, duration: FlutterToastr.lengthLong);
            }
            return;
          }
          //退出程序
          SystemNavigator.pop();
        },
        child: Scaffold(
            floatingActionButton: PictureInPictureIcon(proxyServer),
            body: Scaffold(
              appBar: appBar(),
              drawer: DrawerWidget(proxyServer: proxyServer, container: container),
              floatingActionButton: _launchActionButton(),
              body: ValueListenableBuilder(
                  valueListenable: desktop,
                  builder: (context, value, _) {
                    return Column(children: [
                      value.connect ? remoteConnect(value) : const SizedBox(),
                      Expanded(
                          child: RequestListWidget(key: requestStateKey, proxyServer: proxyServer, list: container))
                    ]);
                  }),
            )));
  }

  AppBar appBar() {
    return AppBar(title: MobileSearch(onSearch: (val) => requestStateKey.currentState?.search(val)), actions: [
      IconButton(
          tooltip: localizations.clear,
          icon: const Icon(Icons.cleaning_services_outlined),
          onPressed: () => requestStateKey.currentState?.clean()),
      const SizedBox(width: 2),
      MoreMenu(proxyServer: proxyServer, desktop: desktop),
      const SizedBox(width: 10),
    ]);
  }

  FloatingActionButton _launchActionButton() {
    return FloatingActionButton(
      onPressed: null,
      child: Center(
          child: SocketLaunch(
              proxyServer: proxyServer,
              size: 36,
              startup: proxyServer.configuration.startup,
              serverLaunch: false,
              onStart: () async {
                Vpn.startVpn(
                    Platform.isAndroid ? await localIp() : "127.0.0.1", proxyServer.port, proxyServer.configuration);
              },
              onStop: () => Vpn.stopVpn())),
    );
  }

  showUpgradeNotice() {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    String content = isCN
        ? '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n\n'
            '1. 更改应用程序图标；\n'
            '2. 桌面端记录调整窗口大小和位置；\n'
            '3. 工具箱Javascript代码运行调试；\n'
            '4. 支持生成python requests代码；\n'
            '5. 修复mac重写不能选择文件；\n'
            '6. 高级重放请求支持随机间隔；\n'
            '7. 修复配置外部代理互相转发问题；\n'
            '8. 修复ssl握手包域名为空的导致请求失败问题；\n'
        : 'Tips：By default, HTTPS packet capture will not be enabled. Please install the certificate before enabling HTTPS packet capture。\n\n'
            'Click HTTPS Capture packets(Lock icon)，Choose to install the root certificate and follow the prompts to proceed。\n\n'
            '1. Change app icon；\n'
            '2. Desktop record adjustment of window size and position；\n'
            '3. Toolbox add javascript code run；\n'
            '4. Support generating Python request code；\n'
            '5. Fix Mac rewrite unable to select files;\n'
            '6. Custom repeat request support random interval；\n'
            '7. Fix external proxy to forward to each other issue；\n'
            '8. fix tls client hello data server_name is null bug';
    showAlertDialog(isCN ? '更新内容V1.1.0' : "Update content V1.1.0", content, () {
      widget.appConfiguration.upgradeNoticeV10 = false;
      widget.appConfiguration.flushConfig();
    });
  }

  /// 远程连接
  Widget remoteConnect(RemoteModel value) {
    return Container(
        margin: const EdgeInsets.only(top: 5, bottom: 5),
        height: 55,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) {
            return ConnectRemote(desktop: desktop, proxyServer: proxyServer);
          })),
          child: Text(localizations.remoteConnected(desktop.value.os ?? ''),
              style: Theme.of(context).textTheme.titleMedium),
        ));
  }

  showAlertDialog(String title, String content, Function onClose) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
              scrollable: true,
              actions: [
                TextButton(
                    onPressed: () {
                      onClose.call();
                      Navigator.pop(context);
                    },
                    child: Text(localizations.cancel))
              ],
              title: Text(title, style: const TextStyle(fontSize: 18)),
              content: Text(content));
        });
  }

  /// 检查远程连接
  checkConnectTask(BuildContext context) async {
    int retry = 0;
    Timer.periodic(const Duration(milliseconds: 3000), (timer) async {
      if (desktop.value.connect == false) {
        timer.cancel();
        return;
      }

      try {
        var response = await HttpClients.get("http://${desktop.value.host}:${desktop.value.port}/ping")
            .timeout(const Duration(seconds: 1));
        if (response.bodyAsString == "pong") {
          retry = 0;
          return;
        }
      } catch (e) {
        retry++;
      }

      if (retry > 5) {
        timer.cancel();
        desktop.value = RemoteModel(connect: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(localizations.remoteConnectDisconnect),
              action: SnackBarAction(
                  label: localizations.reconnect, onPressed: () => desktop.value = RemoteModel(connect: true))));
        }
      }
    });
  }
}
