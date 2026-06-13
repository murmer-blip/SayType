@preconcurrency import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import SayTypeCore

enum CoreAudioInputDeviceError: LocalizedError {
    case noInputDevices
    case missingAudioUnit
    case couldNotSelectDevice(AudioInputCandidate, OSStatus)

    var errorDescription: String? {
        switch self {
        case .noInputDevices:
            "No usable microphone input device was found."
        case .missingAudioUnit:
            "Could not access the macOS microphone audio unit."
        case let .couldNotSelectDevice(candidate, status):
            "Could not use \(candidate.name) for microphone input. CoreAudio status \(status)."
        }
    }
}

enum CoreAudioInputDevice {
    static func applyPreferredInput(to engine: AVAudioEngine) throws -> AudioInputCandidate {
        guard let selected = preferredInputDevice() else {
            throw CoreAudioInputDeviceError.noInputDevices
        }

        guard let audioUnit = engine.inputNode.audioUnit else {
            throw CoreAudioInputDeviceError.missingAudioUnit
        }

        var deviceID = AudioDeviceID(selected.id)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw CoreAudioInputDeviceError.couldNotSelectDevice(selected, status)
        }

        return selected
    }

    static func preferredInputDevice() -> AudioInputCandidate? {
        AudioInputSelector.preferredInput(from: inputDevices())
    }

    static func inputDevices() -> [AudioInputCandidate] {
        let defaultInputID = defaultInputDeviceID()
        return deviceIDs().map { deviceID in
            AudioInputCandidate(
                id: deviceID,
                name: stringProperty(kAudioObjectPropertyName, for: deviceID),
                manufacturer: stringProperty(kAudioObjectPropertyManufacturer, for: deviceID),
                inputChannelCount: inputChannelCount(for: deviceID),
                transport: inputTransport(for: deviceID),
                isDefault: defaultInputID == deviceID
            )
        }
    }

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )
        guard sizeStatus == noErr, dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        let dataStatus = ids.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else {
                return kAudioHardwareUnspecifiedError
            }
            return AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }
        guard dataStatus == noErr else {
            return []
        }
        return ids
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }
        return deviceID
    }

    private static func stringProperty(
        _ selector: AudioObjectPropertySelector,
        for deviceID: AudioDeviceID
    ) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr else {
            return ""
        }
        return value as String? ?? ""
    }

    private static func inputChannelCount(for deviceID: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard sizeStatus == noErr, dataSize > 0 else {
            return 0
        }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        let dataStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, rawPointer)
        guard dataStatus == noErr else {
            return 0
        }

        let buffers = UnsafeMutableAudioBufferListPointer(rawPointer.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(UInt32(0)) { partial, buffer in
            partial + buffer.mNumberChannels
        }
    }

    private static func inputTransport(for deviceID: AudioDeviceID) -> AudioInputTransport {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &transport)
        guard status == noErr else {
            return .unknown
        }

        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            return .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetooth
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeVirtual:
            return .virtual
        case kAudioDeviceTransportTypeUnknown:
            return .unknown
        default:
            return .other
        }
    }
}
