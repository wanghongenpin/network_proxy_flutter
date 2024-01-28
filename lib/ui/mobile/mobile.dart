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
import 'package:network_proxy/ui/mobile/menu.dart';
import 'package:network_proxy/ui/mobile/request/list.dart';
import 'package:network_proxy/ui/mobile/request/search.dart';
import 'package:network_proxy/ui/mobile/widgets/connect_remote.dart';
import 'package:network_proxy/ui/mobile/widgets/pip.dart';
import 'package:network_proxy/utils/ip.dart';

class MobileHomePage extends StatefulWidget {
  final Configuration configuration;
  final AppConfiguration appConfiguration;

  const MobileHomePage(this.configuration, this.appConfiguration, {super.key});

  @override
  State<StatefulWidget> createState() {
    return MobileHomeState();
  }
}

///画中画
final ValueNotifier<bool> pictureInPictureNotifier = ValueNotifier(false);

class MobileHomeState extends State<MobileHomePage> implements EventListener, LifecycleListener {
  static GlobalKey<RequestListState> requestStateKey = GlobalKey<RequestListState>();

  /// 远程连接
  final ValueNotifier<RemoteModel> desktop = ValueNotifier(RemoteModel(connect: false));

  late ProxyServer proxyServer;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void onUserLeaveHint() {
    enterPictureInPicture();
  }

  Future<bool> enterPictureInPicture() async {
    if (Vpn.isVpnStarted && !pictureInPictureNotifier.value) {
      if (desktop.value.connect || !Platform.isAndroid || !(await (AppConfiguration.instance)).pipEnabled) {
        return false;
      }

      return PictureInPicture.enterPictureInPictureMode(
          Platform.isAndroid ? await localIp() : "127.0.0.1", proxyServer.port);
    }
    return false;
  }

  @override
  onPictureInPictureModeChanged(bool isInPictureInPictureMode) async {
    if (isInPictureInPictureMode && !pictureInPictureNotifier.value) {
      while (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      pictureInPictureNotifier.value = true;
      return;
    }

    if (!isInPictureInPictureMode && pictureInPictureNotifier.value) {
      Vpn.isRunning().then((value) {
        Vpn.isVpnStarted = value;
        pictureInPictureNotifier.value = false;
      });
    }
  }

  @override
  void onRequest(Channel channel, HttpRequest request) {
    PictureInPicture.addData(request.requestUrl);
    requestStateKey.currentState!.add(channel, request);
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

    if (widget.appConfiguration.upgradeNoticeV7) {
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
        child: ValueListenableBuilder<bool>(
            valueListenable: pictureInPictureNotifier,
            builder: (context, pip, _) {
              if (pip) {
                return Scaffold(body: RequestListWidget(key: requestStateKey, proxyServer: proxyServer));
              }

              return Scaffold(
                  floatingActionButton:
                      widget.appConfiguration.pipEnabled ? PictureInPictureWindow(proxyServer) : const SizedBox(),
                  body: Scaffold(
                    appBar: appBar(),
                    drawer: DrawerWidget(proxyServer: proxyServer),
                    floatingActionButton: _launchActionButton(),
                    body: ValueListenableBuilder(
                        valueListenable: desktop,
                        builder: (context, value, _) {
                          return Column(children: [
                            value.connect ? remoteConnect(value) : const SizedBox(),
                            Expanded(child: RequestListWidget(key: requestStateKey, proxyServer: proxyServer))
                          ]);
                        }),
                  ));
            }));
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
              startup: Vpn.isVpnStarted,
              serverLaunch: false,
              onStart: () async {
                Vpn.startVpn(Platform.isAndroid ? await localIp() : "127.0.0.1", proxyServer.port,
                    backgroundAudioEnable: widget.appConfiguration.iosVpnBackgroundAudioEnable,
                    appList: proxyServer.configuration.appWhitelist);
              },
              onStop: () => Vpn.stopVpn())),
    );
  }

  showUpgradeNotice() {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    String content = isCN
        ? '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n\n'
            '1. 增加当前视图导出；\n'
            '2. 历史记录增加搜索；\n'
            '3. Android返回键进入小窗口；\n'
            '4. Android白名单应用列表展示隐藏图标应用；\n'
            '5. 修复websocket暗黑主题展示不清楚；\n'
        : 'Tips：By default, HTTPS packet capture will not be enabled. Please install the certificate before enabling HTTPS packet capture。\n\n'
            '1. Add current view export;\n'
            '2. History Add Search;\n'
            '3. Android Return key to enter the small window；\n'
            '4. Android Whitelist application list display hidden icon applications；\n'
            '5. Fix websocket dark theme display unclear；\n'
            ;
    showAlertDialog(isCN ? '更新内容V1.0.8' : "Update content V1.0.8", content, () {
      widget.appConfiguration.upgradeNoticeV7 = false;
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

      if (retry > 3) {
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
