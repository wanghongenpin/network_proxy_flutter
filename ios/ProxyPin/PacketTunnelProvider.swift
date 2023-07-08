//
//  PacketTunnelProvider.swift
//  ProxyPin
//
//  Created by 汪红恩 on 2023/7/4.
//

import NetworkExtension


class PacketTunnelProvider: NEPacketTunnelProvider {

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("startTunnel")

        guard let conf = (protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration else{
            NSLog("[ERROR] No ProtocolConfiguration Found")
            exit(EXIT_FAILURE)
        }
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        NSLog(conf.debugDescription)
        //http代理
        let host = conf["proxyHost"] as! String
        let proxyPort =  conf["proxyPort"] as! Int
        let proxySettings = NEProxySettings()
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: host, port: proxyPort)
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: host, port: proxyPort)
        proxySettings.matchDomains = [""]

        networkSettings.proxySettings =  proxySettings

        setTunnelNetworkSettings(networkSettings) {
           error in
           guard error == nil else {
               NSLog(error.debugDescription)
               NSLog("startTunnel Encountered an error setting up the network: \(error.debugDescription)")
               completionHandler(error)
               return
           }
           completionHandler(nil)

       }
        NSLog("startTunnelend")
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            NSLog("handleAppMessage ", messageData.debugDescription)
            handler(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    override func wake() {
        // Add code here to wake up.
    }
}
