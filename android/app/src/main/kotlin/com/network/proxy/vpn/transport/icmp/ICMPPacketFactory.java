package com.network.proxy.vpn.transport.icmp;


import androidx.annotation.NonNull;

import com.network.proxy.vpn.transport.protocol.IP4Header;
import com.network.proxy.vpn.util.PacketUtil;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;


public class ICMPPacketFactory {

    public static ICMPPacket parseICMPPacket(@NonNull ByteBuffer stream) {
        final byte type = stream.get();
        final byte code = stream.get();
        final int checksum = stream.getShort();

        final int identifier = stream.getShort();
        final int sequenceNumber = stream.getShort();

        final byte[] data = new byte[stream.remaining()];
        stream.get(data);

        return new ICMPPacket(type, code, checksum, identifier, sequenceNumber, data);
    }

    public static ICMPPacket buildSuccessPacket(ICMPPacket requestPacket) {
        return new ICMPPacket(
                0,
                0,
                0,
                requestPacket.identifier,
                requestPacket.sequenceNumber,
                requestPacket.data
        );
    }

    public static byte[] packetToBuffer(IP4Header ipHeader, ICMPPacket packet) {
        byte[] ipData = ipHeader.toBytes();

        ByteArrayOutputStream icmpDataBuffer = new ByteArrayOutputStream();
        icmpDataBuffer.write(packet.type);
        icmpDataBuffer.write(packet.code);

        icmpDataBuffer.write(asShortBytes(0 /* checksum placeholder */), 0, 2);

        if (packet.type == ICMPPacket.ECHO_REQUEST_TYPE || packet.type == ICMPPacket.ECHO_SUCCESS_TYPE) {
            icmpDataBuffer.write(asShortBytes(packet.identifier), 0, 2);
            icmpDataBuffer.write(asShortBytes(packet.sequenceNumber), 0, 2);

            byte[] extraData = packet.data;
            icmpDataBuffer.write(extraData, 0, extraData.length);
        } else {
            throw new IllegalArgumentException("Can't serialize unrecognized ICMP packet type");
        }

        byte[] icmpPacketData = icmpDataBuffer.toByteArray();
        byte[] checksum = PacketUtil.INSTANCE.calculateChecksum(icmpPacketData, 0, icmpPacketData.length);

        ByteBuffer resultBuffer = ByteBuffer.allocate(ipData.length + icmpPacketData.length);
        resultBuffer.put(ipData);
        resultBuffer.put(icmpPacketData);

        // Replace the checksum placeholder
        resultBuffer.position(ipData.length + 2);
        resultBuffer.put(checksum);
        resultBuffer.position(0);

        byte[] result = new byte[resultBuffer.remaining()];
        resultBuffer.get(result);
        return result;
    }

    private static byte[] asShortBytes(int value) {
        return ByteBuffer.allocate(2).putShort((short) value).array();
    }

}
