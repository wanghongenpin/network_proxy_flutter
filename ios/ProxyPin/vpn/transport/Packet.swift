//
//  Packet.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/9/17.
//

import Foundation


class Packet {
    var ipHeader: IP4Header
    var transportHeader: TransportHeader
    var buffer: Data

    init(ipHeader: IP4Header, transportHeader: TransportHeader, buffer: Data) {
        self.ipHeader = ipHeader
        self.transportHeader = transportHeader
        self.buffer = buffer
    }
}
