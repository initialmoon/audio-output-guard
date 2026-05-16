import Foundation

struct LaunchAgent {
    static let label = "dev.audio-output-guard"

    private static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var workingDirectory: URL {
        URL(fileURLWithPath: binaryPath).deletingLastPathComponent()
    }

    static var binaryPath: String {
        executablePath()
    }

    static var plistPath: String {
        homeDirectory.appendingPathComponent("Library/LaunchAgents/\(label).plist").path
    }

    static var stdoutPath: String {
        homeDirectory.appendingPathComponent("Library/Logs/audio-output-guard.log").path
    }

    static var stderrPath: String {
        homeDirectory.appendingPathComponent("Library/Logs/audio-output-guard.err.log").path
    }

    static func install() throws {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw CLIError.runtime("release binary not found at \(binaryPath). Run swift build -c release, then execute the release binary when installing.")
        }
        try FileManager.default.createDirectory(atPath: (plistPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: (stdoutPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try plistData().write(to: URL(fileURLWithPath: plistPath), options: .atomic)
        _ = try? runLaunchctl(arguments: ["bootout", guiDomain(), label], allowFailure: true)
        try runLaunchctl(arguments: ["bootstrap", guiDomain(), plistPath])
        try runLaunchctl(arguments: ["kickstart", "-k", "\(guiDomain())/\(label)"])
        print("installed and started \(label)")
        print("plist: \(plistPath)")
        print("logs: \(stdoutPath)")
    }

    static func uninstall() throws {
        _ = try? runLaunchctl(arguments: ["bootout", guiDomain(), label], allowFailure: true)
        if FileManager.default.fileExists(atPath: plistPath) {
            try FileManager.default.removeItem(atPath: plistPath)
        }
        print("uninstalled \(label)")
    }

    static func status() throws {
        print("LaunchAgent plist: \(FileManager.default.fileExists(atPath: plistPath) ? "installed" : "not installed")")
        print("Binary: \(FileManager.default.isExecutableFile(atPath: binaryPath) ? binaryPath : "not found at \(binaryPath)")")
        let result = runProcess(path: "/bin/launchctl", arguments: ["print", "\(guiDomain())/\(label)"])
        if result.status == 0 {
            print("launchd service: loaded")
            if let pidLine = result.output.split(separator: "\n").first(where: { String($0).trimmingCharacters(in: CharacterSet.whitespaces).hasPrefix("pid =") }) {
                print(String(pidLine).trimmingCharacters(in: CharacterSet.whitespaces))
            }
        } else {
            print("launchd service: not loaded")
        }
        print("stdout log: \(stdoutPath)")
        print("stderr log: \(stderrPath)")
    }

    static func logs(lines: Int) throws {
        print("==> \(stdoutPath)")
        printTail(path: stdoutPath, lines: lines)
        print("==> \(stderrPath)")
        printTail(path: stderrPath, lines: lines)
    }

    private static func plistData() throws -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [binaryPath, "watch"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": stdoutPath,
            "StandardErrorPath": stderrPath,
            "WorkingDirectory": workingDirectory.path
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    @discardableResult
    private static func runLaunchctl(arguments: [String], allowFailure: Bool = false) throws -> String {
        let result = runProcess(path: "/bin/launchctl", arguments: arguments)
        if result.status != 0 && !allowFailure {
            throw CLIError.runtime("launchctl \(arguments.joined(separator: " ")) failed:\n\(result.output)")
        }
        return result.output
    }

    private static func runProcess(path: String, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, "failed to run \(path): \(error)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    private static func printTail(path: String, lines: Int) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("(no log file)")
            return
        }
        let allLines = content.split(separator: "\n", omittingEmptySubsequences: false)
        for line in allLines.suffix(lines) {
            print(line)
        }
    }

    private static func executablePath() -> String {
        let path = CommandLine.arguments[0]
        if path.contains("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        if let pathEnvironment = ProcessInfo.processInfo.environment["PATH"] {
            for directory in pathEnvironment.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(path).standardizedFileURL.path
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func guiDomain() -> String {
        "gui/\(getuid())"
    }
}
