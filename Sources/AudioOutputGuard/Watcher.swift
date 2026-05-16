import CoreAudio
import Foundation

final class Watcher {
    private let client: CoreAudioClient
    private let dryRun: Bool
    private let queue = DispatchQueue(label: "dev.audio-output-guard.coreaudio")
    private var pendingWorkItem: DispatchWorkItem?
    private lazy var reconciler = Reconciler(client: client, dryRun: dryRun)

    init(client: CoreAudioClient, dryRun: Bool) {
        self.client = client
        self.dryRun = dryRun
    }

    func run() throws -> Never {
        try registerListeners()
        print("[\(timestamp())] audio-output-guard watch started\(dryRun ? " in dry-run mode" : "")")
        queue.async { [weak self] in
            self?.runReconcile(reason: "watch startup")
        }
        dispatchMain()
    }

    private func registerListeners() throws {
        let selectors: [(AudioObjectPropertySelector, String)] = [
            (kAudioHardwarePropertyDevices, "device list changed"),
            (kAudioHardwarePropertyDefaultInputDevice, "default input changed"),
            (kAudioHardwarePropertyDefaultOutputDevice, "default output changed"),
            (kAudioHardwarePropertyDefaultSystemOutputDevice, "default system output changed")
        ]

        for (selector, reason) in selectors {
            try client.addSystemListener(selector: selector, queue: queue) { [weak self] in
                self?.scheduleReconcile(reason: reason)
            }
        }
    }

    private func scheduleReconcile(reason: String) {
        pendingWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.runReconcile(reason: reason)
        }
        pendingWorkItem = item
        queue.asyncAfter(deadline: .now() + .milliseconds(400), execute: item)
    }

    private func runReconcile(reason: String) {
        do {
            try reconciler.reconcile(reason: reason)
            fflush(stdout)
        } catch {
            fputs("[\(timestamp())] reconcile failed: \(error)\n", stderr)
            fflush(stderr)
        }
    }

    private func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
