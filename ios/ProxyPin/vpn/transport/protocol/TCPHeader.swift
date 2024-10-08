//
//  TCPHeader.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/9/16.
//

import Foundation

/// Represents a TCP header in a network packet.
class TCPHeader : TransportHeader{
    
    /// Source port number (16 bits)
    var sourcePort: UInt16
    /// Destination port number (16 bits)
    var destinationPort: UInt16
    /// Sequence number (32 bits)
    var sequenceNumber: UInt32
    /// Acknowledgment number (32 bits)
    var ackNumber: UInt32
    /// Data offset (4 bits)
    var dataOffset: UInt8
    var isNS: Bool = false // ECN-nonce concealment protection (experimental: see RFC 3540)
    /// Flags (9 bits)
    var flags: UInt8
    /// Window size (16 bits)
    var windowSize: UInt16
    /// Checksum (16 bits)
    var checksum: UInt16
    /// Urgent pointer (16 bits)
    var urgentPointer: UInt16
    /// Options (variable length)
    var options: Data?
    var payload: Data?

    //Static section for constants
    static let END_OF_OPTIONS_LIST: UInt8 = 0
    static let NO_OPERATION: UInt8 = 1
    static let MAX_SEGMENT_SIZE: UInt8 = 2
    static let WINDOW_SCALE: UInt8 = 3
    static let SELECTIVE_ACK_PERMITTED: UInt8 = 4
    static let TIME_STAMP: UInt8 = 8

    init(sourcePort: UInt16, destinationPort: UInt16, sequenceNumber: UInt32, ackNumber: UInt32, dataOffset: UInt8, isNS: Bool, flags: UInt8, windowSize: UInt16, checksum: UInt16, urgentPointer: UInt16, options: Data?, payload: Data? = nil) {
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.sequenceNumber = sequenceNumber
        self.ackNumber = ackNumber
        self.dataOffset = dataOffset
        self.isNS = isNS
        self.flags = flags
        self.windowSize = windowSize
        self.checksum = checksum
        self.urgentPointer = urgentPointer
        self.options = options
        self.payload = payload
    }

    //options
    var maxSegmentSize: UInt16 = 0
    private var windowScale: UInt8 = 0
    private var isSelectiveAckPermitted = false
    var timeStampSender = 0
    var timeStampReplyTo = 0

    func getSourcePort() -> Int {
        return Int(sourcePort)
    }
    
    func getDestinationPort() -> Int {
        return Int(destinationPort)
    }
    
    func isFIN() -> Bool {
        return flags & 0x01 != 0
    }

    /// Checks if the SYN flag is set.
    func isSYN() -> Bool {
        return flags & 0x02 != 0
    }

    /// Checks if the RST flag is set.
    func isRST() -> Bool {
        return flags & 0x04 != 0
    }

    /// Checks if the PSH flag is set.
    func isPSH() -> Bool {
        return flags & 0x08 != 0
    }

    /// Checks if the ACK flag is set.
    func isACK() -> Bool {
        return flags & 0x10 != 0
    }

    /// Checks if the URG flag is set.
    func isURG() -> Bool {
        return flags & 0x20 != 0
    }

    /// Checks if the ECE flag is set.
    func isECE() -> Bool {
        return flags & 0x40 != 0
    }

    /// Checks if the CWR flag is set.
    func isCWR() -> Bool {
        return flags & 0x80 != 0
    }

    /// Sets or clears the RST flag.
    func setIsRST(_ isRST: Bool) {
        flags = isRST ? (flags | 0x04) : (flags & 0xFB)
    }

    /// Sets or clears the SYN flag.
    func setIsSYN(_ isSYN: Bool) {
        flags = isSYN ? (flags | 0x02) : (flags & 0xFD)
    }

    /// Sets or clears the FIN flag.
    func setIsFIN(_ isFIN: Bool) {
        flags = isFIN ? (flags | 0x01) : (flags & 0xFE)
    }

    /// Sets or clears the PSH flag.
    func setIsPSH(_ isPSH: Bool) {
        flags = isPSH ? (flags | 0x08) : (flags & 0xF7)
    }

    /// Sets or clears the ACK flag.
    func setIsACK(_ isACK: Bool) {
        flags = isACK ? (flags | 0x10) : (flags & 0xEF)
    }

    /// Returns the length of the TCP header.
    func getTCPHeaderLength() -> Int {
        return Int(dataOffset) * 4
    }

    /// Converts the TCP header to a byte array.
    func toBytes() -> Data {
        var buffer = Data()

        buffer.append(contentsOf: sourcePort.bytes)
        buffer.append(contentsOf: destinationPort.bytes)
        buffer.append(contentsOf: sequenceNumber.bytes)
        buffer.append(contentsOf: ackNumber.bytes)

        //is ns and data offset
        let headerLength = 5
        buffer.append(UInt8((headerLength << 4) | (isNS ? 1 : 0)))
        buffer.append(flags)
        buffer.append(contentsOf: windowSize.bytes)
        buffer.append(contentsOf: checksum.bytes)
        buffer.append(contentsOf: urgentPointer.bytes)
//         if let options = options {
//             buffer.append(options)
//         }
        return buffer
    }

    /// Creates a copy of the TCP header.
    func copy() -> TCPHeader {
        return TCPHeader(
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            sequenceNumber: sequenceNumber,
            ackNumber: ackNumber,
            dataOffset: dataOffset,
            isNS: isNS,
            flags: flags,
            windowSize: windowSize,
            checksum: checksum,
            urgentPointer: urgentPointer,
            options: options
        )
    }

}
