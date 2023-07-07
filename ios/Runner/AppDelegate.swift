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

    override func applicationWillTerminate(_ application: UIApplication) {
      VpnManager.shared.disconnect()
    }

   var timer: Timer?
   var bgTask: UIBackgroundTaskIdentifier?


    override func applicationDidEnterBackground(_ application: UIApplication) {
//        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
//        RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
//               bgTask = application.beginBackgroundTask(expirationHandler: nil)
    }

    @objc func timerAction() {
      print(UIApplication.shared.backgroundTimeRemaining )
      if UIApplication.shared.backgroundTimeRemaining < 60.0 {
          let application = UIApplication.shared
          bgTask = application.beginBackgroundTask(expirationHandler: nil)
      }
    }

    var backgroundUpdateTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)
    func endBackgroundUpdateTask() {
        AudioManager.shared.openBackgroundAudioAutoplay = false
        UIApplication.shared.endBackgroundTask(self.backgroundUpdateTask)
        self.backgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
    }

    override func applicationWillResignActive(_ application: UIApplication) {
        AudioManager.shared.openBackgroundAudioAutoplay = true
        self.backgroundUpdateTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.endBackgroundUpdateTask()
        })
    }
    override  func applicationDidBecomeActive(_ application: UIApplication) {
        self.endBackgroundUpdateTask()

    }

}
