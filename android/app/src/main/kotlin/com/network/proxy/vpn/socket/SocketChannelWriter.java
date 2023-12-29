package com.network.proxy.vpn.socket;

import androidx.annotation.NonNull;
import android.util.Log;


import com.network.proxy.vpn.Connection;
import com.network.proxy.vpn.TagKt;
import com.network.proxy.vpn.transport.protocol.TCPPacketFactory;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.DatagramChannel;
import java.nio.channels.NotYetConnectedException;
import java.nio.channels.SelectionKey;
import java.nio.channels.SocketChannel;
import java.nio.channels.spi.AbstractSelectableChannel;


/**
 * Takes a VPN session, and writes all received data from it to the upstream channel.
 * <p>
 * If any writes fail, it resubscribes to OP_WRITE, and tries again next time
 * that fires (as soon as the channel is ready for more data).
 * <p>
 * Used by the NIO thread, and run synchronously as part of that non-blocking loop.
 */
public class SocketChannelWriter {
	private final String TAG = TagKt.getTAG(this);

	private final ClientPacketWriter writer;

	SocketChannelWriter(ClientPacketWriter writer) {
		this.writer = writer;
	}

	public void write(@NonNull Connection connection) {
		AbstractSelectableChannel channel = connection.getChannel();
		if (channel instanceof SocketChannel) {
			writeTCP(connection);
		} else if(channel instanceof DatagramChannel) {
			writeUDP(connection);
		} else {
			// We only ever create TCP & UDP channels, so this should never happen
			throw new IllegalArgumentException("Unexpected channel type: " + channel);
		}

		if (connection.isAbortingConnection()) {
			Log.d(TAG,"removing aborted connection -> " + connection);
			connection.cancelKey();

			if (channel instanceof SocketChannel) {
				try {
					SocketChannel socketChannel = (SocketChannel) channel;
					if (socketChannel.isConnected()) {
						socketChannel.close();
					}
				} catch (IOException e) {
					e.printStackTrace();
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

	private void writeUDP(Connection connection) {
		try {
			writePendingData(connection);
//			Date dt = new Date();
//			connection.connectionStartTime = dt.getTime();
		}catch(NotYetConnectedException ex2){
			connection.setAbortingConnection(true);
			Log.e(TAG,"Error writing to unconnected-UDP server, will abort current connection: "+ex2.getMessage());
		} catch (IOException e) {
			connection.setAbortingConnection(true);
			e.printStackTrace();
			Log.e(TAG,"Error writing to UDP server, will abort connection: "+e.getMessage());
		}
	}
	
	private void writeTCP(Connection connection) {
		try {
			writePendingData(connection);
		} catch (NotYetConnectedException ex) {
			Log.e(TAG,"failed to write to unconnected socket: " + ex.getMessage());
		} catch (IOException e) {
			Log.e(TAG,"Error writing to server: " + e);
			
			//close connection with vpn client
			byte[] rstData = TCPPacketFactory.INSTANCE.createRstData(
					connection.getLastIpHeader(), connection.getLastTcpHeader(), 0);

			writer.write(rstData);

			//remove session
			Log.e(TAG,"failed to write to remote socket, aborting connection");
			connection.setAbortingConnection(true);
		}
	}

	private void writePendingData(Connection connection) throws IOException {
		if (!connection.hasDataToSend()) return;
		AbstractSelectableChannel channel = connection.getChannel();

		byte[] data = connection.getSendingData();
		ByteBuffer buffer = ByteBuffer.allocate(data.length);
		buffer.put(data);
		buffer.flip();

		while (buffer.hasRemaining()) {
			int bytesWritten = channel instanceof SocketChannel
				? ((SocketChannel) channel).write(buffer)
				: ((DatagramChannel) channel).write(buffer);

			if (bytesWritten == 0) {
				break;
			}
		}

		if (buffer.hasRemaining()) {
			// The channel's own buffer is full, so we have to save this for later.
			Log.i(TAG, buffer.remaining() + " bytes unwritten for " + channel);

			// Put the remaining data from the buffer back into the session
			connection.setSendingData(buffer.compact());

			// Subscribe to WRITE events, so we know when this is ready to resume.
			connection.subscribeKey(SelectionKey.OP_WRITE);
		} else {
			// All done, all good -> wait until the next TCP PSH / UDP packet
			connection.setDataForSendingReady(false);

			// We don't need to know about WRITE events any more, we've written all our data.
			// This is safe from races with new data, due to the session lock in NIO.
			connection.unsubscribeKey(SelectionKey.OP_WRITE);
		}
	}
}
