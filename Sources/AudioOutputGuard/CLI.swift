import Foundation

enum CLIError: Error {
    case usage(String)
    case runtime(String)

    var message: String {
        switch self {
        case .usage(let message):
            return message
        case .runtime(let message):
            return message
        }
    }

    var exitCode: Int32 {
        switch self {
        case .usage:
            return 2
        case .runtime:
            return 1
        }
    }
}

struct CLI {
    func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            printHelp()
            return
        }

        let rest = Array(arguments.dropFirst())
        switch command {
        case "help", "--help", "-h":
            printHelp()
        case "devices":
            try runDevices(arguments: rest)
        case "once":
            try runOnce(arguments: rest)
        case "watch":
            try runWatch(arguments: rest)
        case "install":
            try runInstall(arguments: rest)
        case "uninstall":
            try runUninstall(arguments: rest)
        case "status":
            try runStatus(arguments: rest)
        case "logs":
            try runLogs(arguments: rest)
        default:
            throw CLIError.usage("unknown command: \(command)\n\n\(helpText)")
        }
    }

    private func runDevices(arguments: [String]) throws {
        try requireNoArguments(arguments)
        let client = CoreAudioClient()
        let snapshot = try client.snapshot()
        DevicePrinter.printDevices(snapshot)
    }

    private func runOnce(arguments: [String]) throws {
        let dryRun = try parseDryRun(arguments)
        let reconciler = Reconciler(client: CoreAudioClient(), dryRun: dryRun)
        try reconciler.reconcile(reason: "manual once")
    }

    private func runWatch(arguments: [String]) throws {
        let dryRun = try parseDryRun(arguments)
        let watcher = Watcher(client: CoreAudioClient(), dryRun: dryRun)
        try watcher.run()
    }

    private func runInstall(arguments: [String]) throws {
        try requireNoArguments(arguments)
        try LaunchAgent.install()
    }

    private func runUninstall(arguments: [String]) throws {
        try requireNoArguments(arguments)
        try LaunchAgent.uninstall()
    }

    private func runStatus(arguments: [String]) throws {
        try requireNoArguments(arguments)
        try LaunchAgent.status()
    }

    private func runLogs(arguments: [String]) throws {
        let lines = try parseLogLines(arguments)
        try LaunchAgent.logs(lines: lines)
    }

    private func parseDryRun(_ arguments: [String]) throws -> Bool {
        var dryRun = false
        for argument in arguments {
            switch argument {
            case "--dry-run":
                dryRun = true
            default:
                throw CLIError.usage("unknown option for command: \(argument)")
            }
        }
        return dryRun
    }

    private func parseLogLines(_ arguments: [String]) throws -> Int {
        var lines = 100
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--lines":
                guard let value = iterator.next(), let parsed = Int(value), parsed > 0 else {
                    throw CLIError.usage("--lines requires a positive integer")
                }
                lines = parsed
            default:
                throw CLIError.usage("unknown option for logs: \(argument)")
            }
        }
        return lines
    }

    private func requireNoArguments(_ arguments: [String]) throws {
        guard arguments.isEmpty else {
            throw CLIError.usage("unexpected argument: \(arguments[0])")
        }
    }

    private func printHelp() {
        print(helpText)
    }

    private var helpText: String {
        """
        audio-output-guard

        Usage:
          audio-output-guard devices
          audio-output-guard once [--dry-run]
          audio-output-guard watch [--dry-run]
          audio-output-guard install
          audio-output-guard uninstall
          audio-output-guard status
          audio-output-guard logs [--lines N]
        """
    }
}
