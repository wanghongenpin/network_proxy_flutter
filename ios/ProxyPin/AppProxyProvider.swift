//
//  AppProxyProvider.swift
//  ProxyPin
//
//  Created by 汪红恩 on 2023/7/2.
//

import NetworkExtension

class AppProxyProvider: NEAppProxyProvider {

    override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
     
    }
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping() -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        // Add code here to handle the incoming flow.
        return false
    }
}
