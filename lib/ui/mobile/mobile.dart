/*
 * Copyright 2023 WangHongEn
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

///移动端首页
///@author wanghongen
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
      List<String>? appList =
          proxyServer.configuration.appWhitelistEnabled ? proxyServer.configuration.appWhitelist : [];
      List<String>? disallowApps;
      if (appList.isEmpty) {
        disallowApps = proxyServer.configuration.appBlacklist ?? [];
      }

      return PictureInPicture.enterPictureInPictureMode(
          Platform.isAndroid ? await localIp() : "127.0.0.1", proxyServer.port,
          appList: appList, disallowApps: disallowApps);
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

    if (widget.appConfiguration.upgradeNoticeV12) {
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
              appBar: PreferredSize(preferredSize: const Size.fromHeight(42), child: appBar()),
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
                //ios端口可能会被系统杀掉
                if (Platform.isIOS) {
                  await proxyServer.restart();
                }

                Vpn.startVpn(
                    Platform.isAndroid ? await localIp(readCache: false) : "127.0.0.1", proxyServer.port, proxyServer.configuration);
              },
              onStop: () => Vpn.stopVpn())),
    );
  }

  showUpgradeNotice() {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    String content = isCN
        ? '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n\n'
            '1. 桌面端增加全部请求列表；\n'
            '2. iOS 通知栏显示VPN状态；\n'
            '3. iOS修复停止长时间切换后台再开启抓包无网络问题；\n'
            '4. 桌面端保存调整左右面板比例；\n'
            '5. 手机端请求列表增加滚动条；\n'
            '6. 修复请求重发和脚本导致URL错误；\n'
            '7. 修复脚本二进制body转换问题；\n'
            '8. 修复请求编辑中文路径编码问题；\n'
        : 'Tips：By default, HTTPS packet capture will not be enabled. Please install the certificate before enabling HTTPS packet capture。\n\n'
            'Click HTTPS Capture packets(Lock icon)，Choose to install the root certificate and follow the prompts to proceed。\n\n'
            '1. Desktop: Add all requests list；\n'
            '2. iOS notification bar displays VPN status；\n'
            '3. iOS fix: Stop switching to the background for a long time and then start packet capture without network problem；\n'
            '4. Desktop: save the left and right panel ratio；\n'
            '5. Mobile：Add a scrollbar to the request list；\n'
            '6. fix request repeat & script change url wrong；\n'
            '7. fix script binary body convert；\n'
            '';
    showAlertDialog(isCN ? '更新内容V1.1.2' : "Update content V1.1.2", content, () {
      widget.appConfiguration.upgradeNoticeV12 = false;
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
              content: SelectableText(content));
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
