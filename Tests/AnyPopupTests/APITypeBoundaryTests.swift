import Foundation
import XCTest

final class APITypeBoundaryTests: XCTestCase {
    func testTopConfigurationCanUseDetents() throws {
        let result = try typecheck(
            """
            import AnyPopup
            let config = TopPopupConfig().detents([.fixed(200), .large])
            _ = config
            """
        )

        XCTAssertEqual(result.status, 0, result.output)
    }

    func testCenterConfigurationCannotUseDetents() throws {
        let result = try typecheck(
            """
            import AnyPopup
            let config = CenterPopupConfig().detents([.large])
            _ = config
            """
        )

        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.output.contains("has no member 'detents'"), result.output)
    }

    func testAnchoredConfigurationCannotEnterContainerPresentation() throws {
        let result = try typecheck(
            """
            import AnyPopup
            let presentation = ContainerPopupPresentation.anchored(AnchoredPopupConfig())
            _ = presentation
            """
        )

        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.output.contains("has no member 'anchored'"), result.output)
    }

    func testContainerPopupOnlyHasPlainPresent() throws {
        let valid = try typecheck(popupFixture(
            config: "ContainerPopupConfig.center()",
            call: "await ExamplePopup().setCustomID(\"menu\").dismissAfter(1).dismissKeyboardOnDismissal(false).present()"
        ))
        let invalid = try typecheck(popupFixture(
            config: "ContainerPopupConfig.center()",
            call: "await ExamplePopup().present(anchoredTo: \"menu\")"
        ))

        XCTAssertEqual(valid.status, 0, valid.output)
        XCTAssertNotEqual(invalid.status, 0)
    }

    func testAnchoredPopupOnlyHasAnchoredPresent() throws {
        let valid = try typecheck(popupFixture(
            config: "AnchoredPopupConfig()",
            call: "await ExamplePopup().setCustomID(\"menu\").dismissAfter(1).present(anchoredTo: \"button\")"
        ))
        let invalid = try typecheck(popupFixture(
            config: "AnchoredPopupConfig()",
            call: "await ExamplePopup().present()"
        ))

        XCTAssertEqual(valid.status, 0, valid.output)
        XCTAssertNotEqual(invalid.status, 0)
    }
}

private extension APITypeBoundaryTests {
    struct TypecheckResult {
        let status: Int32
        let output: String
    }

    func typecheck(_ source: String) throws -> TypecheckResult {
        let fileManager = FileManager.default
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildRoot = packageRoot.appending(path: ".build")
        guard let enumerator = fileManager.enumerator(
            at: buildRoot,
            includingPropertiesForKeys: nil
        ), let moduleURL = enumerator.compactMap({ $0 as? URL }).first(where: {
            $0.lastPathComponent == "AnyPopup.swiftmodule"
        }) else {
            throw TypecheckError.moduleNotFound
        }

        let fixtureURL = fileManager.temporaryDirectory
            .appending(path: "AnyPopup-Typecheck-(UUID().uuidString).swift")
        try source.write(to: fixtureURL, atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(at: fixtureURL) }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "swiftc",
            "-typecheck",
            "-I", moduleURL.deletingLastPathComponent().path,
            fixtureURL.path
        ]
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return TypecheckResult(
            status: process.terminationStatus,
            output: String(decoding: data, as: UTF8.self)
        )
    }

    enum TypecheckError: Error {
        case moduleNotFound
    }

    func popupFixture(config: String, call: String) -> String {
        """
        import AnyPopup
        import SwiftUI
        struct ExamplePopup: Popup {
            let popupConfig = \(config)
            var body: some View { Text("Example") }
        }
        @MainActor func run() async {
            \(call)
        }
        """
    }
}
