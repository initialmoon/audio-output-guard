import Foundation

let cli = CLI()

do {
    try cli.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch let error as CLIError {
    FileHandle.standardError.write(Data((error.message + "\n").utf8))
    exit(error.exitCode)
} catch {
    FileHandle.standardError.write(Data(("error: \(error)\n").utf8))
    exit(1)
}
