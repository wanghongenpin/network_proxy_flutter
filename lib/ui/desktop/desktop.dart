import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/domain.dart';
import 'package:network_proxy/ui/desktop/left/favorite.dart';
import 'package:network_proxy/ui/component/toolbox.dart';
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

  late ProxyServer proxyServer;
  late NetworkTabController panel;

  final List<NavigationRailDestination> destinations = const [
    NavigationRailDestination(icon: Icon(Icons.workspaces), label: Text("抓包", style: TextStyle(fontSize: 12))),
    // NavigationRailDestination(icon: Icon(Icons.history), label: Text("历史", style: TextStyle(fontSize: 12))),
    NavigationRailDestination(icon: Icon(Icons.favorite), label: Text("收藏", style: TextStyle(fontSize: 12))),
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
    proxyServer = ProxyServer(widget.configuration, listener: this);
    panel = NetworkTabController(tabStyle: const TextStyle(fontSize: 16), proxyServer: proxyServer);

    if (widget.configuration.upgradeNoticeV2) {
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
                  left: PageView(
                      controller: pageController, children: [domainWidget, Favorites(panel: panel), const Toolbox()]),
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
                      widget.configuration.upgradeNoticeV2 = false;
                      widget.configuration.flushConfig();
                      Navigator.pop(context);
                    },
                    child: const Text('关闭'))
              ],
              title: const Text('更新内容V1.0.2', style: TextStyle(fontSize: 18)),
              content: const Text(
                  '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                  '点击的HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。\n\n'
                  '新增更新:\n'
                  '1. 增加工具箱，提供常用编解码，增加HTTP请求,可粘贴cURL格式解析发起请求；\n'
                  '2. 请求编辑发送可直接查看响应体，发送请求无需开启代理；\n'
                  '3. 详情增加快速请求重写, 复制cURL格式可直接导入Postman；\n'
                  '4. 增加请求收藏功能；\n'
                  '5. 主题增加Material3切换；\n'
                  '6. 请求删除&大响应体直接转发;',
                  style: TextStyle(fontSize: 14)));
        });
  }
}
