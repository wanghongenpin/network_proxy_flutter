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
import 'package:network_proxy/ui/configuration.dart';
import 'package:network_proxy/ui/content/panel.dart';
import 'package:network_proxy/ui/desktop/left/favorite.dart';
import 'package:network_proxy/ui/desktop/left/history.dart';
import 'package:network_proxy/ui/desktop/left/list.dart';
import 'package:network_proxy/ui/desktop/preference.dart';
import 'package:network_proxy/ui/desktop/toolbar/toolbar.dart';
import 'package:network_proxy/utils/listenable_list.dart';
import 'package:url_launcher/url_launcher.dart';

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

    if (widget.appConfiguration.upgradeNoticeV10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showUpgradeNotice();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    DomainList(key: domainStateKey, proxyServer: proxyServer, panel: panel, list: container),
                    Favorites(panel: panel),
                    KeepAliveWrapper(
                        child: HistoryPageWidget(proxyServer: proxyServer, container: container, panel: panel)),
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
            width: localizations.localeName == 'zh' ? 58 : 72,
            decoration:
                BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 0.2))),
            child: Column(children: <Widget>[
              SizedBox(
                height: 320,
                child: leftNavigation(index),
              ),
              Expanded(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                      message: localizations.preference,
                      preferBelow: false,
                      child: IconButton(
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (_) => Preference(widget.appConfiguration, proxyServer.configuration));
                          },
                          icon: Icon(Icons.settings_outlined, color: Colors.grey.shade500))),
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

  //left menu eg: requests, favorites, history, toolbox
  Widget leftNavigation(int index) {
    return NavigationRail(
        minWidth: 58,
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
                      widget.appConfiguration.upgradeNoticeV10 = false;
                      widget.appConfiguration.flushConfig();
                      Navigator.pop(context);
                    },
                    child: Text(localizations.cancel))
              ],
              title: Text(isCN ? '更新内容V1.1.0' : "Update content V1.1.0", style: const TextStyle(fontSize: 18)),
              content: Text(
                  isCN
                      ? '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                          '点击HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。\n\n'
                          '1. 更改应用程序图标；\n'
                          '2. 桌面端记录调整窗口大小和位置；\n'
                          '3. 工具箱Javascript代码运行调试；\n'
                          '4. 支持生成python requests代码；\n'
                          '5. 修复mac重写不能选择文件；\n'
                          '6. 高级重放请求支持随机间隔；\n'
                          '7. 修复配置外部代理互相转发问题；\n'
                          '8. 修复ssl握手包域名为空的导致请求失败问题；\n'
                      : 'Tips：By default, HTTPS packet capture will not be enabled. Please install the certificate before enabling HTTPS packet capture。\n'
                          'Click HTTPS Capture packets(Lock icon)，Choose to install the root certificate and follow the prompts to proceed。\n\n'
                          '1. Change app icon；\n'
                          '2. Desktop record adjustment of window size and position；\n'
                          '3. Toolbox add javascript code run；\n'
                          '4. Support generating Python request code；\n'
                          '5. Fix Mac rewrite unable to select files;\n'
                          '6. Custom repeat request support random interval；\n'
                          '7. Fix external proxy to forward to each other issue；\n'
                          '8. fix tls client hello data server_name is null bug',
                  style: const TextStyle(fontSize: 14)));
        });
  }
}
