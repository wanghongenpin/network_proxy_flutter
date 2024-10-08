//
//  QueueFactory.swift
//  ProxyPin
//
//  Created by wanghongen on 2024/9/17.
//

import Foundation

class QueueFactory {
    static let instance = QueueFactory()

    private let queue: DispatchQueue

    private init() {
        queue = DispatchQueue(label: "com.network.ProxyPin.queue")
    }

    func getQueue() -> DispatchQueue {
        return queue
    }

    func executeAsync(block: @escaping () -> Void) {
        queue.async {
            block()
        }
    }

}
