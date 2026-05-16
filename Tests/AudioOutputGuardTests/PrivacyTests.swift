import XCTest

final class PrivacyTests: XCTestCase {
    func testSourceDoesNotContainDeveloperLocalHomePath() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = packageRoot.appendingPathComponent("Sources")
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: sourceRoot, includingPropertiesForKeys: nil)
        var offenders: [String] = []

        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: file, encoding: .utf8)
            let localHome = FileManager.default.homeDirectoryForCurrentUser.path
            if content.contains(localHome) {
                offenders.append(file.path)
            }
        }

        XCTAssertTrue(offenders.isEmpty, "Source files contain local developer home paths: \(offenders)")
    }
}
