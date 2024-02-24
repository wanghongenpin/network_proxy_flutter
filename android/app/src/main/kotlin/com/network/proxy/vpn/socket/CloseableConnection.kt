package com.network.proxy.vpn.socket

import com.network.proxy.vpn.Connection

interface CloseableConnection {
    /**
     * 关闭连接
     */
    fun closeConnection(connection: Connection)
}