import CoreAudio
import Foundation

enum CoreAudioError: Error, CustomStringConvertible {
    case osStatus(OSStatus, String)
    case missingProperty(String)

    var description: String {
        switch self {
        case .osStatus(let status, let operation):
            return "\(operation) failed with OSStatus \(status)"
        case .missingProperty(let property):
            return "missing CoreAudio property: \(property)"
        }
    }
}

final class CoreAudioClient {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let propertyElement = AudioObjectPropertyElement(kAudioObjectPropertyElementMain)

    func snapshot() throws -> AudioSnapshot {
        let defaultInput = try readDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
        let defaultOutput = try readDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
        let defaultSystemOutput = try readDefaultDevice(selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
        let devices = try deviceIDs().map { id in
            try readDevice(id: id, defaultInput: defaultInput, defaultOutput: defaultOutput, defaultSystemOutput: defaultSystemOutput)
        }
        return AudioSnapshot(devices: devices, defaultInput: defaultInput, defaultOutput: defaultOutput, defaultSystemOutput: defaultSystemOutput)
    }

    func setDefaultInput(_ id: AudioObjectID) throws {
        try setDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice, id: id, label: "set default input")
    }

    func setDefaultOutput(_ id: AudioObjectID) throws {
        try setDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice, id: id, label: "set default output")
    }

    func setDefaultSystemOutput(_ id: AudioObjectID) throws {
        try setDefaultDevice(selector: kAudioHardwarePropertyDefaultSystemOutputDevice, id: id, label: "set default system output")
    }

    func addSystemListener(selector: AudioObjectPropertySelector, queue: DispatchQueue, handler: @escaping () -> Void) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: propertyElement
        )
        let status = AudioObjectAddPropertyListenerBlock(systemObject, &address, queue) { _, _ in
            handler()
        }
        try check(status, "add listener \(selector)")
    }

    private func deviceIDs() throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: propertyElement
        )
        var dataSize: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize), "get device list size")
        guard dataSize > 0 else { return [] }
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = Array(repeating: AudioObjectID(0), count: count)
        try ids.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            try check(AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, baseAddress), "get device list")
        }
        return ids.filter { $0 != kAudioObjectUnknown }
    }

    private func readDevice(id: AudioObjectID, defaultInput: AudioObjectID?, defaultOutput: AudioObjectID?, defaultSystemOutput: AudioObjectID?) throws -> AudioDevice {
        let name = (try? readString(deviceID: id, selector: kAudioDevicePropertyDeviceNameCFString)) ?? "(unknown)"
        let uid = (try? readString(deviceID: id, selector: kAudioDevicePropertyDeviceUID)) ?? ""
        let manufacturer = (try? readString(deviceID: id, selector: kAudioObjectPropertyManufacturer)) ?? ""
        let transportType = try? readUInt32(deviceID: id, selector: kAudioDevicePropertyTransportType)
        let isAlive = ((try? readUInt32(deviceID: id, selector: kAudioDevicePropertyDeviceIsAlive)) ?? 0) != 0
        let inputChannels = (try? channelCount(deviceID: id, scope: kAudioDevicePropertyScopeInput)) ?? 0
        let outputChannels = (try? channelCount(deviceID: id, scope: kAudioDevicePropertyScopeOutput)) ?? 0
        return AudioDevice(
            id: id,
            name: name,
            uid: uid,
            manufacturer: manufacturer,
            transportType: transportType,
            isAlive: isAlive,
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            isDefaultInput: id == defaultInput,
            isDefaultOutput: id == defaultOutput,
            isDefaultSystemOutput: id == defaultSystemOutput
        )
    }

    private func readDefaultDevice(selector: AudioObjectPropertySelector) throws -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: propertyElement
        )
        guard AudioObjectHasProperty(systemObject, &address) else { return nil }
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &deviceID), "read default device")
        return deviceID == kAudioObjectUnknown ? nil : deviceID
    }

    private func setDefaultDevice(selector: AudioObjectPropertySelector, id: AudioObjectID, label: String) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: propertyElement
        )
        var mutableID = id
        let dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectSetPropertyData(systemObject, &address, 0, nil, dataSize, &mutableID), label)
    }

    private func readString(deviceID: AudioObjectID, selector: AudioObjectPropertySelector) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: propertyElement
        )
        guard AudioObjectHasProperty(deviceID, &address) else {
            throw CoreAudioError.missingProperty("string selector \(selector)")
        }
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value), "read string selector \(selector)")
        guard let value else { return "" }
        return value.takeUnretainedValue() as String
    }

    private func readUInt32(deviceID: AudioObjectID, selector: AudioObjectPropertySelector) throws -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: propertyElement
        )
        guard AudioObjectHasProperty(deviceID, &address) else {
            throw CoreAudioError.missingProperty("uint32 selector \(selector)")
        }
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value), "read uint32 selector \(selector)")
        return value
    }

    private func channelCount(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) throws -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: propertyElement
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return 0 }
        var dataSize: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize), "get stream configuration size")
        guard dataSize > 0 else { return 0 }
        let bufferList = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferList.deallocate() }
        try check(AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferList), "get stream configuration")
        let audioBufferList = bufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw CoreAudioError.osStatus(status, operation)
        }
    }
}
