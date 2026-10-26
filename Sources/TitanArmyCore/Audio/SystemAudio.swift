import AudioToolbox
import CoreAudio
import Foundation

public struct AudioEndpoint: Identifiable, Equatable, Sendable, Codable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let transport: UInt32
    public let isAlive: Bool
    public let outputChannels: Int
    public var isTitanArmyAudio: Bool { uid == SystemAudio.driverUID }
    public var isBuiltIn: Bool { transport == kAudioDeviceTransportTypeBuiltIn }
}

public enum AudioRoutingError: Error, LocalizedError {
    case coreAudio(String, OSStatus)
    case driverMissing
    case displayAudioMissing
    case ambiguousDisplayAudio
    case unsupportedVolume
    case routeNotReady

    public var errorDescription: String? {
        switch self {
        case let .coreAudio(operation, status): return "\(operation) failed (Core Audio \(status))."
        case .driverMissing: return "Install the Titan Army audio component first."
        case .displayAudioMissing: return "The display’s audio output is unavailable."
        case .ambiguousDisplayAudio: return "More than one audio output matches this display."
        case .unsupportedVolume: return "This output does not expose a system volume control."
        case .routeNotReady: return "The audio component is still connecting to the display."
        }
    }
}

/// Standard Core Audio endpoints. No DDC writes and no interception of media keys.
public enum SystemAudio {
    public static let driverUID = "TitanArmyAudio_Device_v1"
    public static let targetUIDSelector: AudioObjectPropertySelector = 0x74756964 // 'tuid'
    public static let preferences = UserDefaults(suiteName: "local.titanarmy.control.audio")!

    public static func address(_ selector: AudioObjectPropertySelector,
                               scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                               element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        .init(mSelector: selector, mScope: scope, mElement: element)
    }

    public static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var property = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout.size(ofValue: value))
        let status = AudioObjectGetPropertyData(object, &property, 0, nil, &size, &value)
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    public static func uint(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var property = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(object, &property, 0, nil, &size, &value) == noErr ? value : nil
    }

    public static func endpoints() -> [AudioEndpoint] {
        var property = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            let channels = outputChannels(id)
            guard channels > 0, let uid = string(id, kAudioDevicePropertyDeviceUID) else { return nil }
            return AudioEndpoint(id: id, uid: uid, name: string(id, kAudioObjectPropertyName) ?? uid,
                                 transport: uint(id, kAudioDevicePropertyTransportType) ?? 0,
                                 isAlive: uint(id, kAudioDevicePropertyDeviceIsAlive) == 1,
                                 outputChannels: channels)
        }
    }

    private static func outputChannels(_ device: AudioDeviceID) -> Int {
        var property = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &property, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let storage = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { storage.deallocate() }
        guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, storage) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(storage.assumingMemoryBound(to: AudioBufferList.self))
            .reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    public static func defaultOutputID(systemSounds: Bool = false) -> AudioDeviceID? {
        uint(AudioObjectID(kAudioObjectSystemObject), systemSounds ? kAudioHardwarePropertyDefaultSystemOutputDevice : kAudioHardwarePropertyDefaultOutputDevice)
    }

    public static func setDefaultOutput(_ id: AudioDeviceID, systemSounds: Bool = false) throws {
        var property = address(systemSounds ? kAudioHardwarePropertyDefaultSystemOutputDevice : kAudioHardwarePropertyDefaultOutputDevice)
        var value = id
        try check(AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil,
                                            UInt32(MemoryLayout.size(ofValue: value)), &value), "Select audio output")
    }

    public static func volume(_ device: AudioDeviceID) -> Float? {
        var property = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioObjectPropertyScopeOutput)
        var value: Float = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr,
              value.isFinite else { return nil }
        return min(max(value, 0), 1)
    }

    public static func setVolume(_ value: Float, on device: AudioDeviceID) throws {
        guard value.isFinite else { throw AudioRoutingError.unsupportedVolume }
        var property = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioObjectPropertyScopeOutput)
        var value = min(max(value, 0), 1)
        try check(AudioObjectSetPropertyData(device, &property, 0, nil,
                                                     UInt32(MemoryLayout.size(ofValue: value)), &value), "Set system volume")
        if value > 0 { try setMuted(false, on: device) }
    }

    public static func diagnostics(_ device: AudioDeviceID) -> [String: Any]? {
        var property = address(0x746d6574) // 'tmet', read-only counters, no audio recording.
        var value: Unmanaged<CFDictionary>?
        var size = UInt32(MemoryLayout.size(ofValue: value))
        guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as? [String: Any]
    }

    public static func muted(_ device: AudioDeviceID) -> Bool {
        var property = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr && value != 0
    }

    public static func setMuted(_ muted: Bool, on device: AudioDeviceID) throws {
        var property = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)
        var value: UInt32 = muted ? 1 : 0
        try check(AudioObjectSetPropertyData(device, &property, 0, nil,
                                            UInt32(MemoryLayout.size(ofValue: value)), &value), "Set system mute")
    }

    public static func targetUID(_ proxy: AudioDeviceID) -> String? { string(proxy, targetUIDSelector) }

    public static func setTargetUID(_ uid: String, on proxy: AudioDeviceID) throws {
        guard uid != driverUID, !uid.isEmpty, uid.utf8.count <= 512 else { throw AudioRoutingError.displayAudioMissing }
        var property = address(targetUIDSelector)
        let value = uid as CFString
        try withUnsafePointer(to: value) { pointer in
            try check(AudioObjectSetPropertyData(proxy, &property, 0, nil, UInt32(MemoryLayout<CFString>.size), pointer), "Connect display audio")
        }
    }

    public static func matchingDisplay(_ name: String, in endpoints: [AudioEndpoint]) throws -> AudioEndpoint {
        let matches = endpoints.filter { endpoint in
            !endpoint.isTitanArmyAudio && endpoint.isAlive && endpoint.outputChannels >= 2
                && endpoint.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard !matches.isEmpty else { throw AudioRoutingError.displayAudioMissing }
        guard matches.count == 1 else { throw AudioRoutingError.ambiguousDisplayAudio }
        return matches[0]
    }

    /// Explicit user action only. Device-list notifications never steal the user's current output.
    public static func enable(for target: AudioEndpoint) throws {
        let devices = endpoints()
        guard !target.isTitanArmyAudio, target.isAlive else { throw AudioRoutingError.displayAudioMissing }
        guard let proxy = devices.first(where: \.isTitanArmyAudio) else { throw AudioRoutingError.driverMissing }
        let oldOutput = devices.first { $0.id == defaultOutputID() }
        let oldSystem = devices.first { $0.id == defaultOutputID(systemSounds: true) }
        if oldOutput?.isTitanArmyAudio != true {
            preferences.set(oldOutput?.uid, forKey: "previousOutputUID")
            preferences.set(oldSystem?.uid, forKey: "previousSystemOutputUID")
        }
        if targetUID(proxy.id) != target.uid { try setTargetUID(target.uid, on: proxy.id) }
        preferences.set(target.uid, forKey: "targetUID")
        // New installs start at a moderate software level; never change the panel's hardware volume.
        try setDefaultOutput(proxy.id)
        do {
            try setDefaultOutput(proxy.id, systemSounds: true)
        } catch {
            if let oldOutput { try? setDefaultOutput(oldOutput.id) }
            throw error
        }
        preferences.set(true, forKey: "enabled")
    }

    public static func disable() throws {
        let devices = endpoints()
        guard let proxy = devices.first(where: \.isTitanArmyAudio) else {
            preferences.set(false, forKey: "enabled")
            return
        }
        let fallback = devices.first { $0.uid == preferences.string(forKey: "previousOutputUID") && $0.isAlive }
            ?? devices.first { $0.isBuiltIn && $0.isAlive }
        guard let fallback else { throw AudioRoutingError.displayAudioMissing }
        if defaultOutputID() == proxy.id { try setDefaultOutput(fallback.id) }
        if defaultOutputID(systemSounds: true) == proxy.id {
            let system = devices.first { $0.uid == preferences.string(forKey: "previousSystemOutputUID") && $0.isAlive } ?? fallback
            try setDefaultOutput(system.id, systemSounds: true)
        }
        preferences.set(false, forKey: "enabled")
    }

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw AudioRoutingError.coreAudio(operation, status) }
    }
}

/// Retains/removes the exact callback blocks; callbacks never touch DDC or the audio render thread.
public final class AudioPropertyObservation {
    private var registrations: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    public init(objects: [(AudioObjectID, AudioObjectPropertyAddress)], onChange: @escaping @Sendable () -> Void) {
        for (object, var property) in objects {
            let block: AudioObjectPropertyListenerBlock = { _, _ in onChange() }
            if AudioObjectAddPropertyListenerBlock(object, &property, .main, block) == noErr {
                registrations.append((object, property, block))
            }
        }
    }
    deinit {
        for (object, var property, block) in registrations {
            AudioObjectRemovePropertyListenerBlock(object, &property, .main, block)
        }
    }
}
