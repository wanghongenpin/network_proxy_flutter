import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/component/state_component.dart';
import 'package:network_proxy/ui/component/toolbox.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/domain.dart';
import 'package:network_proxy/ui/desktop/left/favorite.dart';
import 'package:network_proxy/ui/desktop/left/history.dart';
import 'package:network_proxy/ui/desktop/toolbar/toolbar.dart';

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

  final List<NavigationRailDestination> destinations = const [
    NavigationRailDestination(icon: Icon(Icons.workspaces), label: Text("抓包", style: TextStyle(fontSize: 12))),
    NavigationRailDestination(icon: Icon(Icons.favorite), label: Text("收藏", style: TextStyle(fontSize: 12))),
    NavigationRailDestination(icon: Icon(Icons.history), label: Text("历史", style: TextStyle(fontSize: 12))),
    NavigationRailDestination(icon: Icon(Icons.construction), label: Text("工具箱", style: TextStyle(fontSize: 12))),
  ];

  @override
  void onRequest(Channel channel, HttpRequest request) {
    domainStateKey.currentState!.add(channel, request);
  }

  @override
  void onResponse(Channel channel, HttpResponse response) {
    domainStateKey.currentState!.addResponse(channel, response);
  }

  @override
  void initState() {
    super.initState();
    proxyServer.addListener(this);
    panel = NetworkTabController(tabStyle: const TextStyle(fontSize: 16), proxyServer: proxyServer);

    if (widget.configuration.upgradeNoticeV3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUpgradeNotice();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainWidget = DomainWidget(key: domainStateKey, proxyServer: proxyServer, panel: panel);
    return Scaffold(
        appBar: Tab(child: Toolbar(proxyServer, domainStateKey, sideNotifier: _selectIndex)),
        body: Row(
          children: [
            ValueListenableBuilder(
                valueListenable: _selectIndex,
                builder: (_, index, __) {
                  if (_selectIndex.value == -1) {
                    return const SizedBox();
                  }
                  return Container(
                      decoration: BoxDecoration(
                          border: Border(
                        right: BorderSide(color: Theme.of(context).dividerColor, width: 0.2),
                      )),
                      width: 55,
                      child: leftNavigation(index));
                }),
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
                      widget.configuration.upgradeNoticeV3 = false;
                      widget.configuration.flushConfig();
                      Navigator.pop(context);
                    },
                    child: const Text('关闭'))
              ],
              title: const Text('更新内容V1.0.3', style: TextStyle(fontSize: 18)),
              content: const Text(
                  '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                  '点击的HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。\n\n'
                  '新增更新:\n'
                  '1. 增加历史记录功能,默认不会保存,需要去历史页点击保存；\n'
                  '2. 请求重写增加名称&URL参数重写；\n'
                  '3. 请求重写增加重定向；\n'
                  '4. 建立连接异常显示请求体；\n'
                  '5. 请求编辑重发响应体查看增加多种格式，详情Body体增加快速解码入口；',
                  style: TextStyle(fontSize: 14)));
        });
  }
}
