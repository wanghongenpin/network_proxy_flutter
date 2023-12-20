//
//  AppLifecycleChannel.swift
//
//  Created by wanghongen on 2023/12/21.
//

import Foundation
import FlutterMacOS

class AppLifecycleChannel {
    static private var channel : FlutterMethodChannel?
    
    //注册
    static func registerChannel(flutterViewController: FlutterViewController) {
        channel = FlutterMethodChannel(name: "com.proxy/appLifecycle", binaryMessenger: flutterViewController.engine.binaryMessenger)
    }
    
    static func appDetached()  {
        channel!.invokeMethod("appDetached", arguments: nil)
        Thread.sleep(forTimeInterval: 0.5)
    }
}
