//
//  ProxySocketIOService.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/9/17.
//

import Foundation
import NetworkExtension
import os.log

class SocketIOService {
//    private static let maxReceiveBufferSize = 16384
    private static let maxReceiveBufferSize = 1024

    private let queue: DispatchQueue = DispatchQueue(label: "ProxyPin.SocketIOService", attributes: .concurrent)

    private var clientPacketWriter: NEPacketTunnelFlow

    private var shutdown = false

    init(clientPacketWriter: NEPacketTunnelFlow) {
        self.clientPacketWriter = clientPacketWriter
    }

    public func stop() {
        os_log("Stopping SocketIOService", log: OSLog.default, type: .default)
        queue.async(flags: .barrier) {
            self.shutdown = true
        }
        queue.suspend()
    }

    //从connection接受数据 写到client
    public func registerSession(connection: Connection) {
        connection.channel!.stateUpdateHandler = { state in
            switch state {

            case .ready:
                connection.isConnected = true
                os_log("Connected to %{public}@ on receiveMessage", log: OSLog.default, type: .default, connection.description)
                //接受远程服务器的数据
                connection.sendToDestination()
                self.receiveMessage(connection: connection)
            case .cancelled:
                connection.isConnected = false
//                os_log("Connection cancelled", log: OSLog.default, type: .default)
                connection.closeConnection()
            case .failed(let error):
                connection.isConnected = false
                os_log("Failed to connect: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
                connection.closeConnection()
            default:
                break
            }
        }

        connection.channel!.start(queue: self.queue)
    }

    private func receiveMessage(connection: Connection) {
        if (shutdown) {
            os_log("SocketIOService is shutting down", log: OSLog.default, type: .default)
            return
        }

        if (connection.nwProtocol == .UDP) {
            readUDP(connection: connection)
        } else {
            readTCP(connection: connection)
        }

        if (connection.isAbortingConnection) {
            os_log("Connection is aborting", log: OSLog.default, type: .default)
            connection.closeConnection()
            return
        }
    }

    func readTCP(connection: Connection) {
//         os_log("Reading from TCP socket")
        if connection.isAbortingConnection {
            os_log("Connection is aborting", log: OSLog.default, type: .default)
            return
        }

        queue.async {
            guard let channel = connection.channel else {
                os_log("Invalid channel type", log: OSLog.default, type: .error)
                return
            }
            
            channel.receive(minimumIncompleteLength: 0, maximumLength: Self.maxReceiveBufferSize) { (data, context, isComplete, error) in
//                os_log("Received TCP data packet %{public}@ length %d", log: OSLog.default, type: .default, connection.description, data?.count ?? 0)
                if let error = error {
                    os_log("Failed to read from TCP socket: %@", log: OSLog.default, type: .error, error as CVarArg)
                    self.sendFin(connection: connection)
                    connection.isAbortingConnection = true
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    return
                }

                self.pushDataToClient(buffer: data, connection: connection)

                // Recursively call readTCP to continue reading messages
                self.receiveMessage(connection: connection)
                
                if (isComplete) {
                    self.sendFin(connection: connection)
                    connection.isAbortingConnection = true
                    return
                }
            }
        }
    }
    
    func synchronized(_ lock: AnyObject, closure: () -> Void) {
//        objc_sync_enter(lock)
        closure()
//        objc_sync_exit(lock)
    }
    
    ///create packet data and send it to VPN client
    private func pushDataToClient(buffer: Data, connection: Connection) {
        // Last piece of data is usually smaller than MAX_RECEIVE_BUFFER_SIZE. We use this as a
        // trigger to set PSH on the resulting TCP packet that goes to the VPN.

        connection.hasReceivedLastSegment = buffer.count < Self.maxReceiveBufferSize

        guard let ipHeader = connection.lastIpHeader, let tcpHeader = connection.lastTcpHeader else {
            os_log("Invalid ipHeader or tcpHeader", log: OSLog.default, type: .error)
            return
        }

        synchronized(connection) {
            let unAck = connection.sendNext
            //处理益处问题
            let nextUnAck = UInt32(truncatingIfNeeded: (connection.sendNext + UInt32(buffer.count)) % UInt32.max)
            connection.sendNext = nextUnAck

            let data = TCPPacketFactory.createResponsePacketData(
                ipHeader: ipHeader,
                tcpHeader: tcpHeader,
                packetData: buffer,
                isPsh: connection.hasReceivedLastSegment,
                ackNumber: connection.recSequence,
                seqNumber: unAck,
                timeSender: connection.timestampSender,
                timeReplyTo: connection.timestampReplyTo
            )

            self.clientPacketWriter.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
//             os_log("Sent TCP data packet to client %{public}@ length:%d ack:%u", log: OSLog.default, type: .default, connection.description, data.count, connection.recSequence)
        }
    }

    private func sendFin(connection: Connection) {
        guard let ipHeader = connection.lastIpHeader, let tcpHeader = connection.lastTcpHeader else {
            os_log("Invalid ipHeader or tcpHeader", log: OSLog.default, type: .error)
            return
        }
        synchronized(connection) {
            let data = TCPPacketFactory.createFinData(
                ipHeader: ipHeader,
                tcpHeader: tcpHeader,
                ackNumber: connection.recSequence,
                seqNumber: connection.sendNext,
                timeSender: connection.timestampSender,
                timeReplyTo: connection.timestampReplyTo
            )
            
            self.clientPacketWriter.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
        }
    }
    
    func readUDP(connection: Connection) {
        queue.async {
            guard let channel = connection.channel else {
                os_log("Invalid channel type", log: OSLog.default, type: .error)
                return
            }

            channel.receive(minimumIncompleteLength: 1, maximumLength: 4196) { (data, context, isComplete, error) in
                if let error = error {
                    os_log("Failed to read from UDP socket: %@", log: OSLog.default, type: .error, error as CVarArg)
                    connection.isAbortingConnection = true
                    return
                }

//                os_log("Received UDP data packet length %d", log: OSLog.default, type: .debug, data?.count ?? 0)

                guard let data = data, !data.isEmpty else {
                    return
                }
                
                
                let packetData = UDPPacketFactory.createResponsePacket(
                    ip: connection.lastIpHeader!,
                    udp: connection.lastUdpHeader!,
                    packetData: data
                )
//                 os_log("Sending UDP data packet to client", log: OSLog.default, type: .default)

                self.clientPacketWriter.writePackets([packetData], withProtocols: [NSNumber(value: AF_INET)])

                // Recursively call receiveMessage to continue receiving messages
                self.receiveMessage(connection: connection)
            }
        }
      }
}
