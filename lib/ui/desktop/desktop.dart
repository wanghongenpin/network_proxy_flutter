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

  final domainStateKey = GlobalKey<DomainWidgetState>();
  final ValueNotifier<int> _selectIndex = ValueNotifier(0);

  late ProxyServer proxyServer = ProxyServer(widget.configuration);
  late NetworkTabController panel;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void onRequest(Channel channel, HttpRequest request) {
    domainStateKey.currentState!.add(channel, request);
  }

  @override
  void onResponse(ChannelContext channelContext, HttpResponse response) {
    domainStateKey.currentState!.addResponse(channelContext, response);
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

    if (widget.appConfiguration.upgradeNoticeV12) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUpgradeNotice();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var navigationView = [
      DomainList(key: domainStateKey, proxyServer: proxyServer, panel: panel, list: container),
      Favorites(panel: panel),
      HistoryPageWidget(proxyServer: proxyServer, container: container, panel: panel),
      const Toolbox()
    ];

    return Scaffold(
        appBar: Tab(child: Toolbar(proxyServer, domainStateKey, sideNotifier: _selectIndex)),
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
                      builder: (_, index, __) => LazyIndexedStack(index: index, children: navigationView)),
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
                      widget.appConfiguration.upgradeNoticeV12 = false;
                      widget.appConfiguration.flushConfig();
                      Navigator.pop(context);
                    },
                    child: Text(localizations.cancel))
              ],
              title: Text(isCN ? '更新内容V1.1.2' : "Update content V1.1.2", style: const TextStyle(fontSize: 18)),
              content: SelectableText(
                  isCN
                      ? '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                          '点击HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。\n\n'
                          '1. iOS 通知栏显示VPN状态；\n'
                          '2. iOS修复停止长时间切换后台再开启抓包无网络问题；\n'
                          '3. 桌面端保存调整左右面板比例；\n'
                          '4. 手机端请求列表增加滚动条；\n'
                          '5. 修复请求重发和脚本导致URL错误；\n'
                          '6. 修复脚本二进制body转换问题；\n'
                          '7. 修复请求编辑中文路径编码问题；\n'
                      : 'Tips：By default, HTTPS packet capture will not be enabled. Please install the certificate before enabling HTTPS packet capture。\n'
                          'Click HTTPS Capture packets(Lock icon)，Choose to install the root certificate and follow the prompts to proceed。\n\n'
                          '1. iOS notification bar displays VPN status；\n'
                          '2. iOS fix: Stop switching to the background for a long time and then start packet capture without network problem；\n'
                          '3. Desktop: save the left and right panel ratio；\n'
                          '4. Mobile：Add a scrollbar to the request list；\n'
                          '5. fix request repeat & script change url wrong；\n'
                          '6. fix script binary body convert；\n'
                          '',
                  style: const TextStyle(fontSize: 14)));
        });
  }
}
