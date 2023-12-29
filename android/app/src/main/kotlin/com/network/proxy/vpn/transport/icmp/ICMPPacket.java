package com.network.proxy.vpn.transport.icmp;


import androidx.annotation.NonNull;

public class ICMPPacket {
    // Two ICMP packets we can handle: simple ping & pong
    public static final byte ECHO_REQUEST_TYPE = 8;
    public static final byte ECHO_SUCCESS_TYPE = 0;

    // One very common packet we ignore: connection rejection. Unclear why this happens,
    // random incoming connections that the phone tries to reply to? Nothing we can do though,
    // as we can't forward ICMP onwards, and we can't usefully respond or react.
    public static final byte DESTINATION_UNREACHABLE_TYPE = 3;

    public final byte type;
    final byte code; // 0 for request, 0 for success, 0 - 15 for error subtypes

    final int checksum;
    final int identifier;
    final int sequenceNumber;

    final byte[] data;

    ICMPPacket(
            int type,
            int code,
            int checksum,
            int identifier,
            int sequenceNumber,
            byte[] data
    ) {
        this.type = (byte) type;
        this.code = (byte) code;
        this.checksum = checksum;
        this.identifier = identifier;
        this.sequenceNumber = sequenceNumber;
        this.data = data;
    }

    @NonNull
    public String toString() {
        return "ICMP packet type " + type + "/" + code + " id:" + identifier +
                " seq:" + sequenceNumber + " and " + data.length + " bytes of data";
    }
}
