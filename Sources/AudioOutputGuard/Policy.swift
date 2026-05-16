import CoreAudio
import Foundation

struct RoutingPlan {
    let desiredInput: AudioObjectID?
    let desiredOutput: AudioObjectID?
    let desiredSystemOutput: AudioObjectID?
    let messages: [String]

    var isNoop: Bool {
        desiredInput == nil && desiredOutput == nil && desiredSystemOutput == nil
    }
}

struct RoutingPolicy {
    func plan(snapshot: AudioSnapshot) -> RoutingPlan {
        let aliveDevices = snapshot.devices.filter(\.isAlive)
        let djiInput = aliveDevices.first { $0.isDJI && $0.hasInput }
        let currentOutput = snapshot.device(id: snapshot.defaultOutput)
        let currentSystemOutput = snapshot.device(id: snapshot.defaultSystemOutput)
        var desiredInput: AudioObjectID?
        var desiredOutput: AudioObjectID?
        var desiredSystemOutput: AudioObjectID?
        var messages: [String] = []

        guard let djiInput else {
            messages.append("DJI microphone is not connected; leaving audio routing unchanged")
            return RoutingPlan(desiredInput: nil, desiredOutput: nil, desiredSystemOutput: nil, messages: messages)
        }

        if snapshot.defaultInput != djiInput.id {
            desiredInput = djiInput.id
            messages.append("set default input to \(djiInput.name)")
        } else {
            messages.append("default input is already \(djiInput.name)")
        }

        if let preferredOutput = choosePreferredOutput(snapshot: snapshot) {
            if snapshot.defaultOutput != preferredOutput.id {
                desiredOutput = preferredOutput.id
                messages.append("set default output to \(preferredOutput.name) because DJI microphone is connected")
            } else {
                messages.append("default output is already preferred: \(preferredOutput.name)")
            }
            if snapshot.defaultSystemOutput != preferredOutput.id {
                desiredSystemOutput = preferredOutput.id
                messages.append("set default system output to \(preferredOutput.name) because DJI microphone is connected")
            }
        } else if currentOutput?.isDJI == true || currentSystemOutput?.isDJI == true {
            messages.append("no safe non-DJI output device found")
        } else {
            messages.append("no preferred output found; leaving current output unchanged")
        }

        return RoutingPlan(desiredInput: desiredInput, desiredOutput: desiredOutput, desiredSystemOutput: desiredSystemOutput, messages: messages)
    }

    private func choosePreferredOutput(snapshot: AudioSnapshot) -> AudioDevice? {
        let candidates = snapshot.devices.filter { $0.isAlive && $0.hasOutput && !$0.isDJI }
        if let headphones = candidates.filter(\.isHeadphoneOutputCandidate).sorted(by: outputSort).first {
            return headphones
        }
        if let builtIn = candidates.filter(\.isBuiltInOutput).sorted(by: outputSort).first {
            return builtIn
        }
        return candidates.sorted(by: outputSort).first
    }

    private func outputSort(_ lhs: AudioDevice, _ rhs: AudioDevice) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

final class Reconciler {
    private let client: CoreAudioClient
    private let dryRun: Bool
    private let policy = RoutingPolicy()

    init(client: CoreAudioClient, dryRun: Bool) {
        self.client = client
        self.dryRun = dryRun
    }

    func reconcile(reason: String) throws {
        let snapshot = try client.snapshot()
        let plan = policy.plan(snapshot: snapshot)
        let prefix = dryRun ? "DRY RUN: " : ""
        print("[\(timestamp())] reconcile: \(reason)")
        for message in plan.messages {
            print("\(prefix)\(message)")
        }
        if plan.isNoop {
            print("\(prefix)no changes needed")
            return
        }
        guard !dryRun else { return }
        if let desiredInput = plan.desiredInput, snapshot.defaultInput != desiredInput {
            try client.setDefaultInput(desiredInput)
        }
        if let desiredOutput = plan.desiredOutput, snapshot.defaultOutput != desiredOutput {
            try client.setDefaultOutput(desiredOutput)
        }
        if let desiredSystemOutput = plan.desiredSystemOutput, snapshot.defaultSystemOutput != desiredSystemOutput {
            try client.setDefaultSystemOutput(desiredSystemOutput)
        }
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
