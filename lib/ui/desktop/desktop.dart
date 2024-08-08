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
  final PageController pageController = PageController();
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
            LeftNavigationBar(
                controller: pageController,
                selectIndex: _selectIndex,
                appConfiguration: widget.appConfiguration,
                proxyServer: proxyServer),
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
              title: Text(isCN ? '更新内容V1.1.1' : "Update content V1.1.1", style: const TextStyle(fontSize: 18)),
              content: Text(
                  isCN
                      ? '提示：默认不会开启HTTPS抓包，请安装证书后再开启HTTPS抓包。\n'
                          '点击HTTPS抓包(加锁图标)，选择安装根证书，按照提示操作即可。\n\n'
                          '1. 支持导入自定义跟证书，以及生成自定义根证书；\n'
                          '2. 支持重新生成根证书，以及重置默认跟证书；\n'
                          '3. 支持导出根证书(p12)和私钥；\n'
                          '4. 历史记录支持重放所有请求；\n'
                          '5. 重放域名下请求；\n'
                          '6. 修复请求重写列表换行问题；\n'
                          '7. 脚本headers支持同名多个值情况；\n'
                      : 'Tips：By default, HTTPS packet capture will not be enabled. Please install the certificate before enabling HTTPS packet capture。\n'
                          'Click HTTPS Capture packets(Lock icon)，Choose to install the root certificate and follow the prompts to proceed。\n\n'
                          '1. Support importing custom certificates and generating custom root certificates；\n'
                          '2. Support generate new root certificates and resetting default  root certificates；\n'
                          '3. Support exporting root certificates and private keys；\n'
                          '4. History supports replaying all requests；\n'
                          '5. Replay domain name request；\n'
                          '6. Fix request rewrite list word wrapping；\n'
                          '7. Script headers support multiple values with the same name；\n'
                          '',
                  style: const TextStyle(fontSize: 14)));
        });
  }
}
