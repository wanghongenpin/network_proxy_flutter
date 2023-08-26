import 'package:flutter/material.dart';
import 'package:network_proxy/network/bin/configuration.dart';
import 'package:network_proxy/network/bin/server.dart';
import 'package:network_proxy/network/channel.dart';
import 'package:network_proxy/network/handler.dart';
import 'package:network_proxy/network/http/http.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/domain.dart';
import 'package:network_proxy/ui/desktop/left/favorite.dart';
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
    NavigationRailDestination(
      icon: Icon(Icons.workspaces),
      label: Text("抓包", style: TextStyle(fontSize: 12)),
    ),
    // NavigationRailDestination(icon: Icon(Icons.history), label: Text("历史", style: TextStyle(fontSize: 12))),
    NavigationRailDestination(
      icon: Icon(Icons.favorite),
      label: Text("收藏", style: TextStyle(fontSize: 12)),
    ),
    // NavigationRailDestination(icon: Icon(Icons.construction), label: Text("工具箱", style: TextStyle(fontSize: 12))),
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
    panel = NetworkTabController(tabStyle: const TextStyle(fontSize: 18), proxyServer: proxyServer);

    if (widget.configuration.guide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        guideDialog();
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
                        right: BorderSide(color: Theme.of(context).dividerColor, width: 0.3),
                      )),
                      width: 45,
                      child: leftNavigation(index));
                }),
            Expanded(
              child: VerticalSplitView(
                  ratio: 0.3,
                  minRatio: 0.15,
                  maxRatio: 0.9,
                  left: PageView(controller: pageController, children: [domainWidget, Favorites(panel: panel)]),
                  right: panel),
            )
          ],
        ));
  }

  Widget leftNavigation(int index) {
    return NavigationRail(
        minWidth: 45,
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

  //首次引导
  guideDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
              actions: [
                TextButton(
                    onPressed: () {
                      widget.configuration.guide = false;
                      widget.configuration.flushConfig();
                      Navigator.pop(context);
                    },
                    child: const Text('关闭'))
              ],
              title: const Text('提示', style: TextStyle(fontSize: 18)),
              content: const Text(
                  '默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                  '点击的HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。\n\n'
                  '新增更新:\n'
                  '1. 增加高级搜索，点击搜索Icon触发。\n'
                  '2. 显示SSL握手异常、建立连接异常、未知异常等请求。\n'
                  '3.响应体大时异步加载json，请求重写增加域名，修复手机扫码连接未开启代理时不转发问题',
                  style: TextStyle(fontSize: 14)));
        });
  }
}
