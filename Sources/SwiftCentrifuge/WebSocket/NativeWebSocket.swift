//
//  NativeWebSocket.swift
//  SwiftCentrifuge
//
//  Created by Anton Selyanin on 17.01.2021.
//

import Foundation
import Logging


@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
final class NativeWebSocket: NSObject, WebSocket, URLSessionWebSocketDelegate {
    weak var delegate: WebSocketDelegate?

    private let log: Logger
    private let request: URLRequest
    /// The websocket is considered 'active' when `task` is not nil
    private var task: URLSessionWebSocketTask?

    init(request: URLRequest, logLevel: Logger.Level) {
        self.request = request

        var log = Logger(label: "com.centrifugal.centrifuge-swift.NativeWebSocket")
        log.logLevel = logLevel

        self.log = log
    }

    func connect() {
        guard task == nil else {
            log.warning("The websocket is already connected, ignoring connect request")
            return
        }

        log.debug("Connecting...")

        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        task = session.webSocketTask(with: request)
        doRead()
        task?.resume()
    }

    func disconnect() {
        log.debug("Disconnecting...")
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func write(data: Data) {
        guard let task = task else {
            log.warning("Attempted to write to an inactive websocket connection")
            return
        }

        task.send(.data(data), completionHandler: { [weak self] error in
            guard let error = error else { return }
            self?.log.trace("Failed to send message, error: \(error)")
        })
    }

    private func doRead() {
        task?.receive { [weak self] (result) in
            guard let self = self else { return }

            switch result {
                case .success(let message):
                    switch message {
                        case .string:
                            self.log.warning("Received unexpected string packet")
                        case .data(let data):
                            self.log.trace("Received data packet")
                            self.delegate?.webSocketDidReceiveData(data)

                        @unknown default:
                            break
                    }

                case .failure(let error):
                    self.log.trace("Read error: \(error)")
            }

            self.doRead()
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        log.debug("Connected")
        delegate?.webSocketDidConnect()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if let task = self.task, webSocketTask !== task {
            // Ignore callbacks from obsolete tasks
            return
        }

        var serverDisconnect: CentrifugeDisconnectOptions?
        if let reason = reason {
            do {
                let disconnect = try JSONDecoder().decode(CentrifugeDisconnectOptions.self, from: reason)
                serverDisconnect = disconnect
                log.debug("Disconnected with code: \(closeCode.rawValue), reason: \(String(data: reason, encoding: .utf8) ?? "<non-UTF8 string>")")
            } catch {}
        } else {
            log.debug("Disconnected with code: \(closeCode.rawValue)")
        }
        self.task = nil
        delegate?.webSocketDidDisconnect(nil, serverDisconnect)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let message = { error.map({ "\($0)" }) ?? "nil" }
        log.debug("Completed with error: \(message())")

        self.task?.cancel()
        self.task = nil
        delegate?.webSocketDidDisconnect(error, nil)
    }
}
