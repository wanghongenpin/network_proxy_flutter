package com.network.proxy;

import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;

public class VpnSocketProxy {

    FileChannel vpnInput;
    FileChannel vpnOutput;

    public VpnSocketProxy(FileDescriptor fileDescriptor) {
         vpnInput = new FileInputStream(fileDescriptor).getChannel();
         vpnOutput = new FileOutputStream(fileDescriptor).getChannel();
    }



    public void accept(byte[] buffer) throws Exception {
        // Allocate the buffer for a single packet.
        ByteBuffer packet = ByteBuffer.allocate(32767);
        while (true) {
            int read = vpnInput.read(packet);
            if (read > 0) {
                packet.flip();
                packet.clear();
                vpnOutput.write(packet);
                packet.clear();
            } else {
                break;
            }
        }
    }


}
