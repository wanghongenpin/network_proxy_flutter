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

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/websocket.dart';
import 'package:network_proxy/ui/component/toolbox.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/configuration.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left_menus/favorite.dart';
import 'package:network_proxy/ui/desktop/left_menus/history.dart';
import 'package:network_proxy/ui/desktop/left_menus/navigation.dart';
import 'package:network_proxy/ui/desktop/request/list.dart';
import 'package:network_proxy/ui/desktop/toolbar/toolbar.dart';
import 'package:network_proxy/utils/listenable_list.dart';

import '../component/split_view.dart';

/// @author wanghongen
/// 2023/10/8
class DesktopHomePage extends StatefulWidget {
  final Configuration configuration;
  final AppConfiguration appConfiguration;

  const DesktopHomePage(this.configuration, this.appConfiguration, {super.key, required});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePagePageState();
}

class _DesktopHomePagePageState extends State<DesktopHomePage> implements EventListener {
  static final container = ListenableList<HttpRequest>();

  static final GlobalKey<DesktopRequestListState> requestListStateKey = GlobalKey<DesktopRequestListState>();

  final ValueNotifier<int> _selectIndex = ValueNotifier(0);

  late ProxyServer proxyServer = ProxyServer(widget.configuration);
  late NetworkTabController panel;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void onRequest(Channel channel, HttpRequest request) {
    requestListStateKey.currentState!.add(channel, request);
  }

  @override
  void onResponse(ChannelContext channelContext, HttpResponse response) {
    requestListStateKey.currentState!.addResponse(channelContext, response);
  }

  @override
  void onMessage(Channel channel, HttpMessage message, WebSocketFrame frame) {
    if (panel.request.get() == message || panel.response.get() == message) {
      panel.changeState();
    }
  }

  @override
  void initState() {
    super.initState();
    proxyServer.addListener(this);
    panel = NetworkTabController(tabStyle: const TextStyle(fontSize: 16), proxyServer: proxyServer);

    if (widget.appConfiguration.upgradeNoticeV13) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUpgradeNotice();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var navigationView = [
      DesktopRequestListWidget(key: requestListStateKey, proxyServer: proxyServer, list: container, panel: panel),
      Favorites(panel: panel),
      HistoryPageWidget(proxyServer: proxyServer, container: container, panel: panel),
      const Toolbox()
    ];

    return Scaffold(
        appBar: Tab(child: Toolbar(proxyServer, requestListStateKey, sideNotifier: _selectIndex)),
        body: Row(
          children: [
            LeftNavigationBar(
                selectIndex: _selectIndex, appConfiguration: widget.appConfiguration, proxyServer: proxyServer),
            Expanded(
              child: VerticalSplitView(
                  ratio: widget.appConfiguration.panelRatio,
                  minRatio: 0.15,
                  maxRatio: 0.9,
                  onRatioChanged: (ratio) {
                    widget.appConfiguration.panelRatio = double.parse(ratio.toStringAsFixed(2));
                    widget.appConfiguration.flushConfig();
                  },
                  left: ValueListenableBuilder(
                      valueListenable: _selectIndex,
                      builder: (_, index, __) =>
                          LazyIndexedStack(index: index < 0 ? 0 : index, children: navigationView)),
                  right: panel),
            )
          ],
        ));
  }

  //更新引导
  showUpgradeNotice() {
    bool isCN = Localizations.localeOf(context) == const Locale.fromSubtags(languageCode: 'zh');

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
              scrollable: true,
              actions: [
                TextButton(
                    onPressed: () {
                      widget.appConfiguration.upgradeNoticeV13 = false;
                      widget.appConfiguration.flushConfig();
                      Navigator.pop(context);
                    },
                    child: Text(localizations.cancel))
              ],
              title: Text(isCN ? '更新内容V1.1.3' : "Update content V1.1.3", style: const TextStyle(fontSize: 18)),
              content: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SelectableText(
                      isCN
                          ? '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                              '点击HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。\n\n'
                              '1. 支持多种主题颜色选择；\n'
                              '2. 外部代理支持身份验证；\n'
                              '3. 双击列表tab滚动到顶部；\n'
                              '4. 修复部分p12证书导入失败的问题；\n'
                              '5. 修复Transfer-Encoding有空格解析错误问题；\n'
                              '6. 脚本增加rawBody原始字节参数, body支持字节数组修改；\n'
                              '7. 修复脚本消息体编码错误导致错误响应；\n'
                              '8. 修复Har导出serverIPAddress不正确；\n'
                              '9. 修复Websocket Response不展示；\n'
                          : 'Tips：By default, HTTPS packet capture will not be enabled. Please install the certificate before enabling HTTPS packet capture。\n'
                              'Click HTTPS Capture packets(Lock icon)，Choose to install the root certificate and follow the prompts to proceed。\n\n'
                              '1. Support multiple theme colors；\n'
                              '2. External proxy support authentication；\n'
                              '3. Double-click the list tab to scroll to the top；\n'
                              '4. Fix the issue of partial p12 certificate import failure；\n'
                              '5. Fix header Transfer-Encoding with spaces；\n'
                              '6. The script add rawBody raw byte parameter, body supports byte array modification；\n'
                              '7. Fix script message body encoding error causing incorrect response；\n'
                              '8. Fix export HAR serverIPAddress incorrect；\n'
                              '9. Fix Websocket Response not displayed；\n'
                              '',
                      style: const TextStyle(fontSize: 14))));
        });
  }
}
