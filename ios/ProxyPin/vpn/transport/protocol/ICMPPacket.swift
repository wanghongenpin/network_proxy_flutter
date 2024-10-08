//
//  ICMPPacket.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/10/3.
//

import Foundation

class ICMPPacket {
    // Two ICMP packets we can handle: simple ping & pong
    static let ECHO_REQUEST_TYPE: UInt8 = 8
    static let ECHO_SUCCESS_TYPE: UInt8 = 0

    // One very common packet we ignore: connection rejection. Unclear why this happens,
    // random incoming connections that the phone tries to reply to? Nothing we can do though,
    // as we can't forward ICMP onwards, and we can't usefully respond or react.
    static let DESTINATION_UNREACHABLE_TYPE: UInt8 = 3

    let type: UInt8
    let code: UInt8 // 0 for request, 0 for success, 0 - 15 for error subtypes
    let checksum: UInt16
    let identifier: UInt16
    let sequenceNumber: UInt16
    let data: [UInt8]

    init(type: UInt8, code: UInt8, checksum: UInt16, identifier: UInt16, sequenceNumber: UInt16, data: [UInt8]) {
        self.type = type
        self.code = code
        self.checksum = checksum
        self.identifier = identifier
        self.sequenceNumber = sequenceNumber
        self.data = data
    }

    var description: String {
        return "ICMP packet type \(type)/\(code) id:\(identifier) seq:\(sequenceNumber) and \(data.count) bytes of data"
    }
}


class ICMPPacketFactory {
    
    static func parseICMPPacket(_ stream: inout Data) -> ICMPPacket? {
        guard stream.count >= 8 else { return nil }
        
        let type = stream.removeFirst()
        let code = stream.removeFirst()
        let checksum = stream.withUnsafeBytes { $0.load(as: UInt16.self) }
        stream.removeFirst(2)
        
        let identifier = stream.withUnsafeBytes { $0.load(as: UInt16.self) }
        stream.removeFirst(2)
        let sequenceNumber = stream.withUnsafeBytes { $0.load(as: UInt16.self) }
        stream.removeFirst(2)
        
        let data = Array(stream)
        
        return ICMPPacket(type: type, code: code, checksum: checksum, identifier: identifier, sequenceNumber: sequenceNumber, data: data)
    }
    
    static func buildSuccessPacket(_ requestPacket: ICMPPacket) -> ICMPPacket {
        return ICMPPacket(
            type: ICMPPacket.ECHO_SUCCESS_TYPE,
            code: 0,
            checksum: 0,
            identifier: requestPacket.identifier,
            sequenceNumber: requestPacket.sequenceNumber,
            data: requestPacket.data
        )
    }
    
    static func packetToBuffer(ipHeader: IP4Header, packet: ICMPPacket) -> Data {
        var buffer = Data()
        buffer.append(ipHeader.toBytes())

        var icmpDataBuffer = Data()
        icmpDataBuffer.append(packet.type)
        icmpDataBuffer.append(packet.code)
        icmpDataBuffer.append(contentsOf: withUnsafeBytes(of: UInt16(0), Array.init))
        
        if packet.type == ICMPPacket.ECHO_REQUEST_TYPE || packet.type == ICMPPacket.ECHO_SUCCESS_TYPE {
            icmpDataBuffer.append(contentsOf: packet.identifier.bytes)
            icmpDataBuffer.append(contentsOf: packet.sequenceNumber.bytes)
            icmpDataBuffer.append(contentsOf: packet.data)
        } else {
            fatalError("Can't serialize unrecognized ICMP packet type")
        }
        
        let checksum = PacketUtil.calculateChecksum(data: icmpDataBuffer, offset: 0, length: icmpDataBuffer.count)
        icmpDataBuffer.replaceSubrange(2..<4, with: checksum)
        buffer.append(icmpDataBuffer)

        return buffer
    }
}
