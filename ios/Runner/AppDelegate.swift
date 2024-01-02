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
        if (!VpnManager.shared.isRunning()) {
            return
        }
        timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
               bgTask = application.beginBackgroundTask(expirationHandler: nil)
    }

    @objc func timerAction() {
        print(UIApplication.shared.backgroundTimeRemaining)
        let application = UIApplication.shared
        if (bgTask != nil) {
            application.endBackgroundTask(bgTask!);
            bgTask = nil;
        }
        
        if (UIApplication.shared.backgroundTimeRemaining < 60 && VpnManager.shared.isRunning()) {
            bgTask = application.beginBackgroundTask(expirationHandler: nil)
        }
            
        if (application.backgroundTimeRemaining <= 0 || application.applicationState == .active) {
            timer?.invalidate();
            timer = nil;
        }
   
    }

    override func applicationWillResignActive(_ application: UIApplication) {
        if (!VpnManager.shared.isRunning()) {
            return
        }
        
        AudioManager.shared.openBackgroundAudioAutoplay = true
        self.backgroundUpdateTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.endBackgroundUpdateTask()
        })
    }
    override  func applicationDidBecomeActive(_ application: UIApplication) {
        self.endBackgroundUpdateTask()
    }
    
    var backgroundUpdateTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)
    func endBackgroundUpdateTask() {
        if (!VpnManager.shared.isRunning()) {
            return
        }
        
        AudioManager.shared.openBackgroundAudioAutoplay = false
        UIApplication.shared.endBackgroundTask(self.backgroundUpdateTask)
        self.backgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
    }

}
