//
//  WebSocket.swift
//  SwiftCentrifuge
//
//

import Foundation

protocol WebSocketDelegate: AnyObject {
    func webSocketDidConnect()
    
    func webSocketDidDisconnect(_ error: Error?, _ disconnectOpts: CentrifugeDisconnectOptions?)
    
    func webSocketDidReceiveData(_ data: Data)
}

protocol WebSocket: AnyObject {
    var delegate: WebSocketDelegate? { get set }
    
    func connect()
    
    func disconnect()
    
    func write(data: Data)
}
