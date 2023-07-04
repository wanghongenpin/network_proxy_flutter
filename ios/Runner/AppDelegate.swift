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

//      let url = URL(string: "http://www.baidu.com")!
//      let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
//          guard let data = data else { return }
//          print(String(data: data, encoding: .utf8)!)
//      }
//      task.resume()

      let controller: FlutterViewController = window.rootViewController as! FlutterViewController ;
      let batteryChannel = FlutterMethodChannel.init(name: "com.proxy/proxyVpn", binaryMessenger: controller as! FlutterBinaryMessenger);
          batteryChannel.setMethodCallHandler({
              (call: FlutterMethodCall, result: FlutterResult) -> Void in
              if ("stopVpn" == call.method) {
                  VpnManager.shared.disconnect()
              } else {
                  let arguments = call.arguments as? Dictionary<String, AnyObject>
                  VpnManager.shared.connect(host: arguments?["proxyHost"] as? String ,port: arguments?["proxyPort"] as? Int)
              }
          })

      
     
     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }


}
