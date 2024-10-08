//
//  CloseableConnection.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/9/17.
//

import Foundation


protocol CloseableConnection {
    /// Closes the connection
    func closeConnection(connection: Connection)
}
