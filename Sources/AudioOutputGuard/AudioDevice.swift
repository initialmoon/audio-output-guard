import CoreAudio
import Foundation

struct AudioDevice: Equatable {
    let id: AudioObjectID
    let name: String
    let uid: String
    let manufacturer: String
    let transportType: UInt32?
    let isAlive: Bool
    let inputChannels: Int
    let outputChannels: Int
    let isDefaultInput: Bool
    let isDefaultOutput: Bool
    let isDefaultSystemOutput: Bool

    var hasInput: Bool { inputChannels > 0 }
    var hasOutput: Bool { outputChannels > 0 }

    var isDJI: Bool {
        let haystack = "\(name) \(uid) \(manufacturer)".lowercased()
        return haystack.contains("dji mic mini") || haystack.contains("dji mic") || haystack.contains("dji")
    }

    var isBuiltInOutput: Bool {
        guard hasOutput else { return false }
        if transportType == kAudioDeviceTransportTypeBuiltIn {
            return true
        }
        let lowerName = name.lowercased()
        return lowerName.contains("macbook") || lowerName.contains("built-in output") || lowerName.contains("built in output") || lowerName.contains("speakers")
    }

    var isHeadphoneOutputCandidate: Bool {
        guard hasOutput, isAlive, !isDJI, !isBuiltInOutput else { return false }
        let lowerName = name.lowercased()
        let nameLooksLikeHeadphones = lowerName.contains("airpods") || lowerName.contains("headphone") || lowerName.contains("headset") || lowerName.contains("earbuds") || lowerName.contains("earbud") || lowerName.contains("sony") || lowerName.contains("bose") || lowerName.contains("beats") || lowerName.contains("wh-") || lowerName.contains("wf-")
        if nameLooksLikeHeadphones {
            return true
        }
        return transportType == kAudioDeviceTransportTypeBluetooth || transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    var transportName: String {
        guard let transportType else { return "unknown" }
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            return "built-in"
        case kAudioDeviceTransportTypeAggregate:
            return "aggregate"
        case kAudioDeviceTransportTypeVirtual:
            return "virtual"
        case kAudioDeviceTransportTypePCI:
            return "pci"
        case kAudioDeviceTransportTypeUSB:
            return "usb"
        case kAudioDeviceTransportTypeFireWire:
            return "firewire"
        case kAudioDeviceTransportTypeBluetooth:
            return "bluetooth"
        case kAudioDeviceTransportTypeBluetoothLE:
            return "bluetooth-le"
        case kAudioDeviceTransportTypeHDMI:
            return "hdmi"
        case kAudioDeviceTransportTypeDisplayPort:
            return "displayport"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplay"
        case kAudioDeviceTransportTypeAVB:
            return "avb"
        case kAudioDeviceTransportTypeThunderbolt:
            return "thunderbolt"
        default:
            return "0x" + String(transportType, radix: 16)
        }
    }
}

struct AudioSnapshot {
    let devices: [AudioDevice]
    let defaultInput: AudioObjectID?
    let defaultOutput: AudioObjectID?
    let defaultSystemOutput: AudioObjectID?

    func device(id: AudioObjectID?) -> AudioDevice? {
        guard let id else { return nil }
        return devices.first { $0.id == id }
    }
}

struct DevicePrinter {
    static func printDevices(_ snapshot: AudioSnapshot) {
        print("ID\tIN*\tOUT*\tSYS*\tIN\tOUT\tTRANSPORT\tNAME\tUID")
        for device in snapshot.devices.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let defaultInput = device.isDefaultInput ? "*" : ""
            let defaultOutput = device.isDefaultOutput ? "*" : ""
            let defaultSystemOutput = device.isDefaultSystemOutput ? "*" : ""
            let input = device.hasInput ? "yes(\(device.inputChannels))" : "no"
            let output = device.hasOutput ? "yes(\(device.outputChannels))" : "no"
            print("\(device.id)\t\(defaultInput)\t\(defaultOutput)\t\(defaultSystemOutput)\t\(input)\t\(output)\t\(device.transportName)\t\(device.name)\t\(device.uid)")
        }
    }
}
