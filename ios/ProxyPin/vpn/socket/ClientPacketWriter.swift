//
//  ClientPacketWriter.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/9/

import Foundation
import NetworkExtension

class ClientPacketWriter: NSObject {
    private var packetFlow: NEPacketTunnelFlow
    private let packetQueue = DispatchQueue(label: "packetQueue", attributes: .concurrent)
    private var isShutdown = false

    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }

    func write(data: Data) {
        if !self.isShutdown {
             packetQueue.async {
                self.packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
            }
        }
    }

    func shutdown() {
        packetQueue.async(flags: .barrier) {
            self.isShutdown = true
        }
    }
}

