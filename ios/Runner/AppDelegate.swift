import UIKit
import Flutter
import NetworkExtension

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
     GeneratedPluginRegistrant.register(with: self)
     
      let manager = NETunnelProviderManager()
      let conf = NETunnelProviderProtocol()
      conf.serverAddress = "https://127.0.0.1"
//      // Include network traffic.
//      let setting = NEProxySettings()
//      setting.httpsEnabled = true
//      setting.httpEnabled = true
//      setting.httpsServer = NEProxyServer.init(address: "127.0.0.1", port:  8888)
//      conf.proxySettings = setting
//      
      manager.protocolConfiguration = conf
      manager.localizedDescription = "ProxyPin"
      manager.isEnabled = true
      
      manager.saveToPreferences {error in
              if error != nil{print("vpn erroor" ,error);return;}
      }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
