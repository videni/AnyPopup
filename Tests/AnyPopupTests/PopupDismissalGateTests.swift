import XCTest
@testable import AnyPopup

@MainActor
final class PopupDismissalGateTests: XCTestCase {
    func testDismissalWaitsForKeyboardBeforeDeparture() async {
        let keyboard = ControllableKeyboardDismissal()
        let gate = PopupDismissalGate()
        var passed = false

        let task = Task { @MainActor in
            await gate.waitBeforeDeparture(
                dismissKeyboard: true,
                keyboard: keyboard
            )
            passed = true
        }
        await Task.yield()

        XCTAssertEqual(keyboard.dismissCallCount, 1)
        XCTAssertFalse(passed)

        keyboard.completeHide()
        await task.value

        XCTAssertTrue(passed)
    }

    func testDismissalSkipsKeyboardWhenPolicyIsDisabled() async {
        let keyboard = ControllableKeyboardDismissal()
        let gate = PopupDismissalGate()

        await gate.waitBeforeDeparture(
            dismissKeyboard: false,
            keyboard: keyboard
        )

        XCTAssertEqual(keyboard.dismissCallCount, 0)
    }

    func testKeyboardDismissalWaitersShareOneHideRequest() async {
        let waiters = PopupKeyboardDismissalWaiters()
        var startCount = 0
        var completionCount = 0

        let first = Task { @MainActor in
            await waiters.wait {
                startCount += 1
                return true
            }
            completionCount += 1
        }
        await Task.yield()
        let second = Task { @MainActor in
            await waiters.wait {
                startCount += 1
                return true
            }
            completionCount += 1
        }
        await Task.yield()

        XCTAssertEqual(startCount, 1)
        XCTAssertEqual(completionCount, 0)

        waiters.resumeAll()
        await first.value
        await second.value

        XCTAssertEqual(completionCount, 2)
    }

    func testKeyboardDismissalWaitersResumeWhenHideCannotStart() async {
        let waiters = PopupKeyboardDismissalWaiters()

        await waiters.wait { false }

        XCTAssertFalse(waiters.isWaiting)
    }
}

@MainActor
private final class ControllableKeyboardDismissal: PopupKeyboardDismissing {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var dismissCallCount = 0

    func dismissAndWait() async {
        dismissCallCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func completeHide() {
        continuation?.resume()
        continuation = nil
    }
}
