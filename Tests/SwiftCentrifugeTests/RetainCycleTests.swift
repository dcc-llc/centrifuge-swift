import XCTest
@testable import SwiftCentrifuge

final class RetainCycleTests: XCTestCase {
    let url = URL(string: "ws://127.0.0.1:8000/connection/websocket?format=protobuf")!
    let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MTAwOTM1MTB9.M9gYGAbrGM5IUjMFzMAmTLVrB517TKYU8hHgBGwfRB0"

    func test_ShouldNotLeakAfterConnect() {
        var client: ClientTester? = makeClient()
        client?.connectAndWait()

        weak var c = client?.client

        client = nil

        XCTAssertNil(c)
    }

    func test_ConnectDisconnect() {
        let client = makeClient()

        client.connectAndWait()
        client.disconnectAndWait()
        client.connectAndWait()
    }

    func test_TwoClients() throws {
        let c1 = makeClient()
        let c2 = makeClient()

        c1.connectAndWait()
        c2.connectAndWait()

        let sub1 = try c1.makeSubscription(for: "chat:index")
        sub1.subscribeAndWait()
        let sub2 = try c2.makeSubscription(for: "chat:index")
        sub2.subscribeAndWait()

        let s = "test".data(using: .utf8)!

        let messageDate = Date()
        sub1.publishAndWait(s)
        sub2.expectMessage(after: messageDate)

        XCTAssertEqual(s, sub2.messages.last!.data)
    }

    func test_TwoClients_Recover() throws {
        let c1 = makeClient()
        let c2 = makeClient()

        c1.connectAndWait()
        c2.connectAndWait()

        let sub1 = try c1.makeSubscription(for: "chat:index")
        sub1.subscribeAndWait()
        let sub2 = try c2.makeSubscription(for: "chat:index")
        sub2.subscribeAndWait()

        c2.disconnectAndWait()

        let s = "test".data(using: .utf8)!
        let messageDate = Date()
        sub1.publishAndWait(s)

        c2.connectAndWait()

        sub2.expectMessage(after: messageDate)

        XCTAssertEqual(s, sub2.messages.last?.data)
    }


    private func makeClient() -> ClientTester {
        let client = ClientTester(url: url, testCase: self)
        client.start(token: token)
        return client
    }
}
