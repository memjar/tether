import XCTest
@testable import TetherEngine

final class NetworkMonitorTests: XCTestCase {
    func testMonitorStarts() {
        let monitor = NetworkMonitor()
        let expectation = XCTestExpectation(description: "Received snapshot")

        monitor.start { snapshot in
            XCTAssertNotNil(snapshot.status)
            XCTAssertFalse(snapshot.interfaces.isEmpty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        monitor.stop()
    }

    func testSnapshotProperties() {
        let monitor = NetworkMonitor()
        let expectation = XCTestExpectation(description: "Snapshot has properties")

        monitor.start { snapshot in
            XCTAssertNotNil(snapshot.statusLabel)
            XCTAssertNotNil(snapshot.timestamp)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        monitor.stop()
    }
}
