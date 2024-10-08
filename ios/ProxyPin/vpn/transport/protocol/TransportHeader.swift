//
//  TransportHeader.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/9/17.
//

import Foundation

protocol TransportHeader {
    func getSourcePort() -> Int
    func getDestinationPort() -> Int
}
