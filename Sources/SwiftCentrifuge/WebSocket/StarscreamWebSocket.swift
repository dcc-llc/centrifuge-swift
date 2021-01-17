//
//  StarscreamWebSocket.swift
//  SwiftCentrifuge
//
//  Created by Anton Selyanin on 17.01.2021.
//

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
