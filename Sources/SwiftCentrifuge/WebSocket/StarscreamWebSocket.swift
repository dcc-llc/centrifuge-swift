//
//  StarscreamWebSocket.swift
//  SwiftCentrifuge
//
//  Created by Anton Selyanin on 17.01.2021.
//

import Foundation
import Starscream

final class StarscreamWebSocket: WebSocket {
    private typealias Socket = Starscream.WebSocket

    weak var delegate: WebSocketDelegate? {
        didSet {
            registerDelegate()
        }
    }

    private let socket: Starscream.WebSocket

    init(request: URLRequest, tlsSkipVerify: Bool) {
        self.socket = Socket(request: request)
        socket.disableSSLCertValidation = tlsSkipVerify
    }

    func connect() {
        socket.connect()
    }

    func disconnect() {
        socket.disconnect()
    }

    func write(data: Data) {
        socket.write(data: data)
    }

    private func registerDelegate() {
        socket.onConnect = { [weak self] in
            self?.delegate?.webSocketDidConnect()
        }
        socket.onDisconnect = { [weak self] error in
            guard let delegate = self?.delegate else { return }

            var serverDisconnect: CentrifugeDisconnectOptions?
            if let err = error as? WSError {
                do {
                    let disconnect = try JSONDecoder().decode(CentrifugeDisconnectOptions.self, from: err.message.data(using: .utf8)!)
                    serverDisconnect = disconnect
                } catch {}
            }
            delegate.webSocketDidDisconnect(error, serverDisconnect)
        }
        socket.onData = { [weak self] data in
            self?.delegate?.webSocketDidReceiveData(data)
        }
    }
}

// Trying to catch an issue with "stale" websockets.
// Reinstantiating a new WebSocket object each time we try to connect to the server
final class StarscreamReinstantiatingWebSocket: WebSocket {
	private typealias Socket = Starscream.WebSocket

	weak var delegate: WebSocketDelegate?

	private var socket: Socket?
	private let request: URLRequest
	private let tlsSkipVerify: Bool
	private let queue: DispatchQueue

	init(request: URLRequest, tlsSkipVerify: Bool, queue: DispatchQueue) {
		self.request = request
		self.tlsSkipVerify = tlsSkipVerify
		self.queue = queue
	}

	func connect() {
		// Unregister from the old socket events
		socket?.delegate = nil

		socket = Socket(request: request)
		socket?.callbackQueue = queue
		socket?.disableSSLCertValidation = tlsSkipVerify
		socket?.delegate = self
		socket?.connect()
	}

	func disconnect() {
		guard let socket = socket else { return }

		let wasConnected = socket.delegate != nil
		socket.delegate = nil
		if wasConnected {
			delegate?.webSocketDidDisconnect(nil, nil)
		}

		// WARNING! Websocket might not be properly closed in this case.
		// Reason: the object could be removed from the memory before sending
		// proper closing commands.
		// Check if this brings any problems
		socket.disconnect()
		self.socket = nil
	}

	func write(data: Data) {
		socket?.write(data: data)
	}
}

extension StarscreamReinstantiatingWebSocket: Starscream.WebSocketDelegate {
	func websocketDidConnect(socket: WebSocketClient) {
		delegate?.webSocketDidConnect()
	}

	func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
		guard let delegate = self.delegate else { return }

		var serverDisconnect: CentrifugeDisconnectOptions?
		if let err = error as? WSError {
			do {
				let disconnect = try JSONDecoder().decode(CentrifugeDisconnectOptions.self, from: err.message.data(using: .utf8)!)
				serverDisconnect = disconnect
			} catch {}
		}
		delegate.webSocketDidDisconnect(error, serverDisconnect)
		socket.delegate = nil
	}

	func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
		// ignore
	}

	func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
		delegate?.webSocketDidReceiveData(data)
	}
}
