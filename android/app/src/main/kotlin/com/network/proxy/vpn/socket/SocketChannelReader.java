package com.network.proxy.vpn.socket;

import androidx.annotation.NonNull;

import android.util.Log;

import com.network.proxy.vpn.Connection;
import com.network.proxy.vpn.TagKt;
import com.network.proxy.vpn.transport.protocol.IP4Header;
import com.network.proxy.vpn.transport.protocol.TCPHeader;
import com.network.proxy.vpn.transport.protocol.TCPPacketFactory;
import com.network.proxy.vpn.transport.protocol.UDPPacketFactory;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.ClosedByInterruptException;
import java.nio.channels.ClosedChannelException;
import java.nio.channels.DatagramChannel;
import java.nio.channels.NotYetConnectedException;
import java.nio.channels.SelectionKey;
import java.nio.channels.SocketChannel;
import java.nio.channels.spi.AbstractSelectableChannel;


/**
 * Takes a session, and reads all available upstream data back into it.
 * Used by the NIO thread, and run synchronously as part of that non-blocking loop.
 */
class SocketChannelReader {

    private final String TAG = TagKt.getTAG(this);

    private final ClientPacketWriter writer;

    public SocketChannelReader(ClientPacketWriter writer) {
        this.writer = writer;
    }

    public void read(Connection connection) {
        AbstractSelectableChannel channel = connection.getChannel();

        if (channel instanceof SocketChannel) {
            readTCP(connection);
        } else if (channel instanceof DatagramChannel) {
            readUDP(connection);
        } else {
            return;
        }

        // Resubscribe to reads, so that we're triggered again if more data arrives later.
        connection.subscribeKey(SelectionKey.OP_READ);

        if (connection.isAbortingConnection()) {
            Log.d(TAG, "removing aborted connection -> " + connection);
            connection.cancelKey();
            if (channel instanceof SocketChannel) {
                try {
                    SocketChannel socketChannel = (SocketChannel) channel;
                    if (socketChannel.isConnected()) {
                        socketChannel.close();
                    }
                } catch (IOException e) {
                    Log.e(TAG, e.toString());
                }
            } else {
                try {
                    DatagramChannel datagramChannel = (DatagramChannel) channel;
                    if (datagramChannel.isConnected()) {
                        datagramChannel.close();
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
            connection.closeConnection();
        }
    }

    private void readTCP(@NonNull Connection connection) {
        if (connection.isAbortingConnection()) {
            return;
        }

        SocketChannel channel = (SocketChannel) connection.getChannel();
        ByteBuffer buffer = ByteBuffer.allocate(Constant.MAX_RECEIVE_BUFFER_SIZE);
        int len;

        try {
            do {
                len = channel.read(buffer);
                if (len > 0) { //-1 mean it reach the end of stream
                    sendToRequester(buffer, len, connection);
                    buffer.clear();
                } else if (len == -1) {
//					Log.d(TAG,"End of data from remote server, will send FIN to client");
                    Log.d(TAG, "send FIN to: " + connection);
                    sendFin(connection);
                    connection.setAbortingConnection(true);
                }
            } while (len > 0);
        } catch (NotYetConnectedException e) {
            Log.e(TAG, "socket not connected");
        } catch (ClosedByInterruptException e) {
            Log.e(TAG, "ClosedByInterruptException reading SocketChannel: " + e.getMessage());
        } catch (ClosedChannelException e) {
            Log.e(TAG, "ClosedChannelException reading SocketChannel: " + e.getMessage());
        } catch (IOException e) {
            Log.e(TAG, "Error reading data from SocketChannel: " + e.getMessage());
            connection.setAbortingConnection(true);
        }
    }

    private void sendToRequester(ByteBuffer buffer, int dataSize, @NonNull Connection connection) {
        // Last piece of data is usually smaller than MAX_RECEIVE_BUFFER_SIZE. We use this as a
        // trigger to set PSH on the resulting TCP packet that goes to the VPN.
        connection.setHasReceivedLastSegment(dataSize < Constant.MAX_RECEIVE_BUFFER_SIZE);

        buffer.limit(dataSize);
        buffer.flip();
        // TODO should allocate new byte array?
        byte[] data = new byte[dataSize];
        System.arraycopy(buffer.array(), 0, data, 0, dataSize);
        connection.addReceivedData(data);
        //pushing all data to vpn client
        while (connection.hasReceivedData()) {
            pushDataToClient(connection);
        }
    }

    /**
     * create packet data and send it to VPN client
     */
    private void pushDataToClient(@NonNull Connection connection) {
        if (!connection.hasReceivedData()) {
            //no data to send
            Log.d(TAG, "no data for vpn client");
        }

        IP4Header ipHeader = connection.getLastIpHeader();
        TCPHeader tcpheader = connection.getLastTcpHeader();
        // TODO What does 60 mean?
        int max = connection.getMaxSegmentSize() - 60;

        if (max < 1) {
            max = 1024;
        }

        byte[] packetBody = connection.getReceivedData(max);
        if (packetBody != null && packetBody.length > 0) {
            long unAck = connection.getSendNext();
            long nextUnAck = connection.getSendNext() + packetBody.length;
            connection.setSendNext((int) nextUnAck);
            //we need this data later on for retransmission
//            connection.setUnackData(packetBody);
//            connection.setResendPacketCounter(0);

            byte[] data = TCPPacketFactory.createResponsePacketData(ipHeader,
                    tcpheader, packetBody, connection.getHasReceivedLastSegment(),
                    connection.getRecSequence(), (int) unAck,
                    connection.getTimestampSender(), connection.getTimestampReplyTo());

            writer.write(data);
        }
    }

    private void sendFin(Connection connection) {
        final IP4Header ipHeader = connection.getLastIpHeader();
        final TCPHeader tcpheader = connection.getLastTcpHeader();
        final byte[] data = TCPPacketFactory.INSTANCE.createFinData(ipHeader, tcpheader,
                connection.getRecSequence(), connection.getSendNext(),
                connection.getTimestampSender(), connection.getTimestampReplyTo());

        writer.write(data);
    }

    private void readUDP(Connection connection) {
        DatagramChannel channel = (DatagramChannel) connection.getChannel();
        ByteBuffer buffer = ByteBuffer.allocate(Constant.MAX_RECEIVE_BUFFER_SIZE);
        int len;

        try {
            do {
                if (connection.isAbortingConnection()) {
                    break;
                }

                len = channel.read(buffer);
                if (len > 0) {
                    buffer.limit(len);
                    buffer.flip();

                    //create UDP packet
                    byte[] data = new byte[len];
                    System.arraycopy(buffer.array(), 0, data, 0, len);
                    byte[] packetData = UDPPacketFactory.createResponsePacket(
                            connection.getLastIpHeader(), connection.getLastUdpHeader(), data);

                    //write to client
                    writer.write(packetData);

                    buffer.clear();
                }
            } while (len > 0);
        } catch (NotYetConnectedException ex) {
            Log.e(TAG, "failed to read from unconnected UDP socket");
        } catch (IOException e) {
            Log.e(TAG, "Failed to read from UDP socket, aborting connection");
            connection.setAbortingConnection(true);
        }
    }
}
