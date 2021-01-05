import XCTest
@testable import SwiftCentrifuge

final class ClientTester {
    let client: CentrifugeClient

    private(set) var isConnected: Bool = false

    private var onConnected: (() -> Void)?
    private var onDisconnected: (() -> Void)?

    private weak var testCase: XCTestCase?

    init(url: URL, testCase: XCTestCase) {
        let config = CentrifugeClientConfig()
        self.client = CentrifugeClient(url: url.absoluteString, config: config)
        self.testCase = testCase

        client.delegate = self
    }

    func start(token: String) {
        client.setToken(token)
    }

    func makeSubscription(for channel: String) throws -> SubscriptionTester {
        let tester = SubscriptionTester(testCase: testCase)
        let subscription = try client.newSubscription(channel: channel, delegate: tester)
        tester.setup(with: subscription)
        return tester
    }

    func connectAndWait() {
        client.connect()
        waitForConnected()
    }

    func disconnectAndWait() {
        client.disconnect()
        waitForDisconnected()
    }

    func waitForConnected() {
        let exp = XCTestExpectation(description: "expect connected")
        self.onConnected = { [weak exp] in
            exp?.fulfill()
        }

        if isConnected {
            exp.fulfill()
        }

        testCase?.wait(for: [exp], timeout: 1)
    }

    func waitForDisconnected() {
        let exp = XCTestExpectation(description: "expect disconnected")
        self.onDisconnected = { [weak exp] in
            exp?.fulfill()
        }

        if !isConnected {
            exp.fulfill()
        }

        testCase?.wait(for: [exp], timeout: 1)
    }
}

extension ClientTester: CentrifugeClientDelegate {
    func onConnect(_ c: CentrifugeClient, _ e: CentrifugeConnectEvent) {
        self.isConnected = true
        print("connected with id", e.client)
        DispatchQueue.main.async { [weak self] in
            self?.onConnected?()
        }
    }

    func onDisconnect(_ c: CentrifugeClient, _ e: CentrifugeDisconnectEvent) {
        self.isConnected = false
        print("disconnected", e.reason, "reconnect", e.reconnect)
        DispatchQueue.main.async { [weak self] in
            self?.onDisconnected?()
        }
    }
}

final class SubscriptionTester {
    typealias Message = (date: Date, data: Data)

    private(set) var subscription: CentrifugeSubscription!
    private(set) var messages: [Message] = []
    private weak var testCase: XCTestCase?

    private var isSubscribed: Bool = false
    private var onSubscribed: (() -> Void)?
//    private var onUnsubscribed: (() -> Void)?
    private var onMessage: ((Message) -> Void)?

    init(testCase: XCTestCase?) {
        self.testCase = testCase
    }

    func setup(with subscription: CentrifugeSubscription) {
        self.subscription = subscription
    }

    func subscribeAndWait() {
        subscription.subscribe()
        waitForSubscribed()
    }

    func waitForSubscribed() {
        let exp = XCTestExpectation(description: "expect subscribed")
        self.onSubscribed = { [weak exp] in
            exp?.fulfill()
        }

        if isSubscribed {
            exp.fulfill()
        }

        testCase?.wait(for: [exp], timeout: 1)
    }

    func publishAndWait(_ data: Data) {
        let exp = XCTestExpectation(description: "expect to publish data")
        subscription.publish(data: data) { error in
            exp.fulfill()
            XCTAssertNil(error)
        }

        testCase?.wait(for: [exp], timeout: 1)
    }

    func expectMessage(after date: Date) {
        if messages.contains(where: { $0.date >= date }) {
            return
        }

        let exp = XCTestExpectation(description: "message after: \(date)")
        onMessage = { [weak exp] message in
            if message.date >= date {
                exp?.fulfill()
            }
        }

        testCase?.wait(for: [exp], timeout: 1)
    }
}

extension SubscriptionTester: CentrifugeSubscriptionDelegate {
    func onPublish(_ s: CentrifugeSubscription, _ e: CentrifugePublishEvent) {
        let data = String(data: e.data, encoding: .utf8) ?? ""
        print("message from channel", s.channel, data)
        DispatchQueue.main.async {
            let message = (date: Date(), data: e.data)
            self.messages.append(message)
            self.onMessage?(message)
        }
    }

    func onSubscribeSuccess(_ s: CentrifugeSubscription, _ e: CentrifugeSubscribeSuccessEvent) {
        s.presence(completion: { result, error in
            if let err = error {
                print("Unexpected presence error: \(err)")
            } else if let presence = result {
                print(presence)
            }
        })
        print("successfully subscribed to channel \(s.channel)")
        isSubscribed = true
        DispatchQueue.main.async {
            self.onSubscribed?()
        }
    }

    func onSubscribeError(_ s: CentrifugeSubscription, _ e: CentrifugeSubscribeErrorEvent) {
        isSubscribed = false
        print("failed to subscribe to channel", e.code, e.message)
    }

    func onUnsubscribe(_ s: CentrifugeSubscription, _ e: CentrifugeUnsubscribeEvent) {
        isSubscribed = false
        print("unsubscribed from channel", s.channel)
    }

    func onJoin(_ s: CentrifugeSubscription, _ e: CentrifugeJoinEvent) {
        print("client joined channel \(s.channel), user ID \(e.user)")
    }

    func onLeave(_ s: CentrifugeSubscription, _ e: CentrifugeLeaveEvent) {
        print("client left channel \(s.channel), user ID \(e.user)")
    }
}
