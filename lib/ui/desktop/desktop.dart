import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/network/http/websocket.dart';
import 'package:network_proxy/ui/component/state_component.dart';
import 'package:network_proxy/ui/component/toolbox.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/favorite.dart';
import 'package:network_proxy/ui/desktop/left/history.dart';
import 'package:network_proxy/ui/desktop/left/list.dart';
import 'package:network_proxy/ui/desktop/toolbar/toolbar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../component/split_view.dart';

class DesktopHomePage extends StatefulWidget {
  final Configuration configuration;

  const DesktopHomePage({super.key, required this.configuration});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePagePageState();
}

class _DesktopHomePagePageState extends State<DesktopHomePage> implements EventListener {
  final domainStateKey = GlobalKey<DomainWidgetState>();
  final PageController pageController = PageController();
  final ValueNotifier<int> _selectIndex = ValueNotifier(0);

  late ProxyServer proxyServer = ProxyServer(widget.configuration);
  late NetworkTabController panel;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  List<NavigationRailDestination> get destinations => [
        NavigationRailDestination(
            padding: const EdgeInsets.only(bottom: 3),
            icon: const Icon(Icons.workspaces),
            label: Text(localizations.requests, style: Theme.of(context).textTheme.bodySmall)),
        NavigationRailDestination(
            padding: const EdgeInsets.only(bottom: 3),
            icon: const Icon(Icons.favorite),
            label: Text(localizations.favorites, style: Theme.of(context).textTheme.bodySmall)),
        NavigationRailDestination(
            padding: const EdgeInsets.only(bottom: 3),
            icon: const Icon(Icons.history),
            label: Text(localizations.history, style: Theme.of(context).textTheme.bodySmall)),
        NavigationRailDestination(
            icon: const Icon(Icons.construction),
            label: Text(localizations.toolbox, style: Theme.of(context).textTheme.bodySmall)),
      ];

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

    if (widget.configuration.upgradeNoticeV6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUpgradeNotice();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainWidget = DomainList(key: domainStateKey, proxyServer: proxyServer, panel: panel);

    return Scaffold(
        appBar: Tab(child: Toolbar(proxyServer, domainStateKey, sideNotifier: _selectIndex)),
        body: Row(
          children: [
            navigationBar(),
            Expanded(
              child: VerticalSplitView(
                  ratio: 0.3,
                  minRatio: 0.15,
                  maxRatio: 0.9,
                  left: PageView(controller: pageController, physics: const NeverScrollableScrollPhysics(), children: [
                    domainWidget,
                    Favorites(panel: panel),
                    KeepAliveWrapper(
                        child: HistoryPageWidget(
                            proxyServer: proxyServer, domainWidgetState: domainStateKey, panel: panel)),
                    const Toolbox()
                  ]),
                  right: panel),
            )
          ],
        ));
  }

  Widget navigationBar() {
    return ValueListenableBuilder(
        valueListenable: _selectIndex,
        builder: (_, index, __) {
          if (_selectIndex.value == -1) {
            return const SizedBox();
          }
          return Container(
            width: localizations.localeName == 'zh' ? 55 : 72,
            decoration:
                BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 0.2))),
            child: Column(children: <Widget>[
              SizedBox(
                height: 300,
                child: leftNavigation(index),
              ),
              Expanded(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  //偏好设置
                  Tooltip(
                      message: localizations.preference,
                      preferBelow: false,
                      child: IconButton(
                          onPressed: () {}, icon: Icon(Icons.settings_outlined, color: Colors.grey.shade500))),
                  const SizedBox(height: 5),
                  Tooltip(
                      preferBelow: true,
                      message: localizations.feedback,
                      child: IconButton(
                        onPressed: () =>
                            launchUrl(Uri.parse("https://github.com/wanghongenpin/network_proxy_flutter/issues")),
                        icon: Icon(Icons.feedback_outlined, color: Colors.grey.shade500),
                      )),
                  const SizedBox(height: 10),
                ],
              ))
            ]),
          );
        });
  }

  Widget leftNavigation(int index) {
    return NavigationRail(
        minWidth: 55,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedIconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        labelType: NavigationRailLabelType.all,
        destinations: destinations,
        selectedIndex: index,
        onDestinationSelected: (int index) {
          pageController.jumpToPage(index);
          _selectIndex.value = index;
        });
  }

  //更新引导
  showUpgradeNotice() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
              scrollable: true,
              actions: [
                TextButton(
                    onPressed: () {
                      widget.configuration.upgradeNoticeV6 = false;
                      widget.configuration.flushConfig();
                      Navigator.pop(context);
                    },
                    child: const Text('关闭'))
              ],
              title: const Text('更新内容V1.0.6', style: TextStyle(fontSize: 18)),
              content: const Text(
                  '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                  '点击的HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。\n\n'
                  '1. 请求重写增加 修改请求，可根据正则替换；\n'
                  '2. 请求重写批量导入、导出；\n'
                  '3. 支持WebSocket抓包；\n'
                  '4. 安卓支持小窗口模式；\n'
                  '5. 优化curl导入；\n'
                  '6. 支持head请求，修复手机端请求重写切换应用恢复原始的请求问题；\n'
                  '',
                  style: TextStyle(fontSize: 14)));
        });
  }
}
