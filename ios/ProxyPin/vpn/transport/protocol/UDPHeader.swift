//
//  UDPHeader.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/9/17.
//

import Foundation
import os.log

///UDP报头的数据
struct UDPHeader {
    var sourcePort: UInt16  //源端口号 16bit
    var destinationPort: UInt16  //源端口号 16bit
    var length: UInt16  //UDP数据报长度 16bit
    var checksum: UInt16 //校验和 16bit

    init(sourcePort: UInt16, destinationPort: UInt16, length: UInt16, checksum: UInt16) {
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.length = length
        self.checksum = checksum
    }
}


class UDPPacketFactory {
    static let UDP_HEADER_LENGTH = 8
    
    static func createUDPHeader(from data: Data) -> UDPHeader? {
        guard data.count >= UDP_HEADER_LENGTH else {
            return nil
        }

        let srcPort = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self).bigEndian }
        let destPort = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self).bigEndian }
        let length = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self).bigEndian }
        let checksum = data.withUnsafeBytes { $0.load(fromByteOffset: 6, as: UInt16.self).bigEndian }

        return UDPHeader(sourcePort: srcPort, destinationPort: destPort, length: length, checksum: checksum)
    }
    
    
    static func createResponsePacket(ip: IP4Header, udp: UDPHeader, packetData: Data?) -> Data {
        var udpLen = 8
        if let packetData = packetData {
            udpLen += packetData.count
        }
        let srcPort = udp.destinationPort
        let destPort = udp.sourcePort
    
        let ipHeader = ip.copy()
        let srcIp = ip.destinationIP
        let destIp = ip.sourceIP

        ipHeader.setMayFragment(false)
        ipHeader.sourceIP = srcIp
        ipHeader.destinationIP = destIp
        ipHeader.identification = UInt16(truncatingIfNeeded: PacketUtil.getPacketId())

        //ip的长度是整个数据包的长度 => IP header length + UDP header length (8) + UDP body length
        let totalLength = ipHeader.getIPHeaderLength() + udpLen
        ipHeader.totalLength = UInt16(totalLength)

        var ipData = ipHeader.toBytes()

        // clear IP checksum
        ipData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            bytes[10] = 0
            bytes[11] = 0
        }

        //os_log("Create UDP response packet from %{public}@:%{public}d to %{public}@:%{public}d totalLength:%{public}d", log: OSLog.default, type: .default, PacketUtil.intToIPAddress(srcIp), srcPort, PacketUtil.intToIPAddress(destIp), destPort, totalLength)

        // calculate checksum for IP header
        let ipChecksum = PacketUtil.calculateChecksum(data: ipData, offset: 0, length: ipData.count)

        // write result of checksum back to buffer
        ipData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            bytes[10] = ipChecksum[0]
            bytes[11] = ipChecksum[1]
        }

        var buffer = Data()

        // copy IP header to buffer
        buffer.append(ipData)

        // copy UDP header to buffer
        buffer.append(contentsOf: srcPort.bytes)
        buffer.append(contentsOf: destPort.bytes)

        buffer.append(contentsOf: UInt16(udpLen).bytes)

        let checksum: UInt16 = 0
        buffer.append(contentsOf: checksum.bytes)

        if let packetData = packetData {
         buffer.append(packetData)
        }
        return buffer
    }

    //打印数据包
    public static func printPacket(data: Data) {
        guard let udpHeader = createUDPHeader(from: data) else {
            return
        }
        os_log("UDP Header: sourcePort: %{public}d, destinationPort: %{public}d, length: %{public}d, checksum: %{public}d", log: OSLog.default, type: .default, udpHeader.sourcePort, udpHeader.destinationPort, udpHeader.length, udpHeader.checksum)
    }
    
}
