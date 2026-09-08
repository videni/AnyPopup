@MainActor
protocol PopupKeyboardDismissing: AnyObject {
    func dismissAndWait() async
}

@MainActor
struct PopupDismissalGate {
    func waitBeforeDeparture(
        dismissKeyboard: Bool,
        keyboard: any PopupKeyboardDismissing
    ) async {
        guard dismissKeyboard else { return }
        await keyboard.dismissAndWait()
    }
}

@MainActor
final class PopupKeyboardDismissalWaiters {
    private var continuations: [CheckedContinuation<Void, Never>] = []

    var isWaiting: Bool {
        !continuations.isEmpty
    }

    func wait(startIfNeeded: () -> Bool) async {
        await withCheckedContinuation { continuation in
            let shouldStart = continuations.isEmpty
            continuations.append(continuation)
            if shouldStart, !startIfNeeded() {
                resumeAll()
            }
        }
    }

    func resumeAll() {
        let pending = continuations
        continuations.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}
