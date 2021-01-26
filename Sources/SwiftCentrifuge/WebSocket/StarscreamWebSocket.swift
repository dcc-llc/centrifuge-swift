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

	weak var delegate: WebSocketDelegate? {
		didSet {
			registerDelegate()
		}
	}

	private var socket: Socket?
	private let request: URLRequest
	private let tlsSkipVerify: Bool

	init(request: URLRequest, tlsSkipVerify: Bool) {
		self.request = request
		self.tlsSkipVerify = tlsSkipVerify
	}

	func connect() {
		if let previous = socket {
			unregisterDelegate(from: previous)
		}

		socket = Socket(request: request)
		socket?.disableSSLCertValidation = tlsSkipVerify
		registerDelegate()
		socket?.connect()
	}

	func disconnect() {
		// Don't unregister event callbacks here, wait for the disconnection event
		socket?.disconnect()
		socket = nil
	}

	func write(data: Data) {
		socket?.write(data: data)
	}

	private func registerDelegate() {
		guard let socket = socket else { return }

		socket.onConnect = { [weak self] in
			self?.delegate?.webSocketDidConnect()
		}
		socket.onDisconnect = { [weak self, weak socket] error in
			guard let delegate = self?.delegate else { return }

			var serverDisconnect: CentrifugeDisconnectOptions?
			if let err = error as? WSError {
				do {
					let disconnect = try JSONDecoder().decode(CentrifugeDisconnectOptions.self, from: err.message.data(using: .utf8)!)
					serverDisconnect = disconnect
				} catch {}
			}
			delegate.webSocketDidDisconnect(error, serverDisconnect)
			if let socket = socket {
				self?.unregisterDelegate(from: socket)
			}
		}
		socket.onData = { [weak self] data in
			self?.delegate?.webSocketDidReceiveData(data)
		}
	}

	private func unregisterDelegate(from socket: Socket) {
		socket.onConnect = nil
		socket.onDisconnect = nil
		socket.onData = nil
	}
}
