import XCTest
@testable import AnyPopup

@MainActor
final class SystemPresentationCoordinatorTests: XCTestCase {
    func testPresentationRestoresPreviousKeyWindowAfterCompletion() async {
        let host = TestSystemPresentationHost()
        let coordinator = SystemPresentationCoordinator(host: host)
        var finish: (@MainActor () -> Void)?

        let task = Task { @MainActor in
            await coordinator.perform { completion in
                finish = completion
            }
        }
        await Task.yield()

        XCTAssertEqual(host.beginCount, 1)
        XCTAssertEqual(host.endCount, 0)

        finish?()
        let outcome = await task.value

        XCTAssertEqual(outcome, .completed)
        XCTAssertEqual(host.endCount, 1)
    }

    func testSceneDisconnectResumesPendingPresentationAndRestoresWindow() async {
        let host = TestSystemPresentationHost()
        let coordinator = SystemPresentationCoordinator(host: host)

        let task = Task { @MainActor in
            await coordinator.perform { _ in }
        }
        await Task.yield()

        coordinator.disconnect()
        let outcome = await task.value

        XCTAssertEqual(outcome, .sceneDisconnected)
        XCTAssertEqual(host.beginCount, 1)
        XCTAssertEqual(host.endCount, 1)
    }

    func testUnavailableOrBusyPresenterFailsWithoutStartingAnotherWindow() async {
        let unavailable = SystemPresentationCoordinator(host: nil)
        let unavailableOutcome = await unavailable.perform { _ in }
        XCTAssertEqual(unavailableOutcome, .unavailable)

        let host = TestSystemPresentationHost()
        let coordinator = SystemPresentationCoordinator(host: host)
        var firstFinish: (@MainActor () -> Void)?
        let first = Task { @MainActor in
            await coordinator.perform { completion in
                firstFinish = completion
            }
        }
        await Task.yield()

        let busyOutcome = await coordinator.perform { _ in }
        XCTAssertEqual(busyOutcome, .busy)

        firstFinish?()
        let firstOutcome = await first.value
        XCTAssertEqual(firstOutcome, .completed)
        XCTAssertEqual(host.beginCount, 1)
        XCTAssertEqual(host.endCount, 1)
    }
}

@MainActor
private final class TestSystemPresentationHost: PopupSystemPresentationHosting {
    var beginCount = 0
    var endCount = 0

    func beginSystemPresentation() {
        beginCount += 1
    }

    func endSystemPresentation() {
        endCount += 1
    }
}
