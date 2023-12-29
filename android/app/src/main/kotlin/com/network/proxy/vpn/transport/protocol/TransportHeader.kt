package com.network.proxy.vpn.transport.protocol

interface TransportHeader {
    fun getSourcePort(): Int
    fun getDestinationPort(): Int
}