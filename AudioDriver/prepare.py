#!/usr/bin/env python3
"""Stage the pinned, Unlicense upstream with Titan Army's auditable adaptations."""
import pathlib, shutil, sys
source = pathlib.Path(__file__).resolve().parents[1] / 'Vendor/ProxyAudioDevice'
target = pathlib.Path(sys.argv[1])
if target.exists(): shutil.rmtree(target)
shutil.copytree(source, target)
h = target/'proxyAudioDevice/ProxyAudioDevice.h'
s = h.read_text()
for old, new in {
    'net.briankendall.ProxyAudioDevice': 'local.titanarmy.audio',
    'ProxyAudioBox_UID': 'TitanArmyAudio_Box_v1',
    'ProxyAudioDevice_UID': 'TitanArmyAudio_Device_v1',
    'ProxyAudioDevice_ModelUID': 'TitanArmyAudio_Model_v1',
    'ActiveCondition::userActive': 'ActiveCondition::proxiedDeviceActive',
    'kOutputDeviceDefaultHideWhenUnavailable false': 'kOutputDeviceDefaultHideWhenUnavailable true',
    'gDevice_SampleRate = 44100.0': 'gDevice_SampleRate = 48000.0',
    'gVolume_Output_L_Value = 0.0': 'gVolume_Output_L_Value = 0.5',
    'gVolume_Output_R_Value = 0.0': 'gVolume_Output_R_Value = 0.5',
    'ProxyAudio_Create': 'TitanArmyAudio_Create',
}.items(): s=s.replace(old,new)
s=s.replace('    void calculateVolumeFactors(', '    void persistVolume();\n    std::atomic<UInt64> volumeStorageGeneration{0};\n    void calculateVolumeFactors(')
h.write_text(s)
p=target/'proxyAudioDevice/ProxyAudioDevice.cpp'
s=p.read_text().replace('ProxyAudio_Create','TitanArmyAudio_Create').replace('net.briankendall.ProxyAudioDevice','local.titanarmy.audio')
s=s.replace('CFSTR("Apple Inc.")','CFSTR("Titan Army")').replace('CFSTR("ManufacturerName")','CFSTR("Titan Army")')
s=s.replace('Proxy Audio Box','Titan Army Audio').replace('Proxy Audio Model','Titan Army Display Audio').replace('Proxy Audio Device','Titan Army Audio')
s=s.replace('    size_t length = CFStringGetLength(s) + 1;', '    size_t length = CFStringGetMaximumSizeForEncoding(CFStringGetLength(s), kCFStringEncodingUTF8) + 1;')
s=s.replace('    delete buffer;', '    delete[] buffer;')
# Never silently forward display audio into an unrelated device.
a=s.index('    // First we check the default output device',s.index('CFStringRef ProxyAudioDevice::copyDefaultProxyOutputDeviceUID()'))
b=s.index('\n}\n',a)
s=s[:a]+'''    for (AudioObjectID device : AudioDevice::devicesWithOutputCapabilitiesThatAreNotProxyAudioDevice()) {
        CFStringSmartRef name = AudioDevice::copyObjectName(device);
        if (name && CFStringFind(name, CFSTR("P275MV"), kCFCompareCaseInsensitive).location != kCFNotFound) {
            return AudioDevice::copyDeviceUID(device);
        }
    }
    return CFStringCreateCopy(NULL, CFSTR(""));'''+s[b:]
s=s.replace('    setupTargetOutputDevice();\n    return noErr;\n}', '''    ExecuteInAudioOutputThread(^{
        // Device discovery / teardown must never re-enter HAL on its notification thread.
        if (!outputDeviceUID || CFStringGetLength(outputDeviceUID) == 0) {
            if (outputDeviceUID) CFRelease(outputDeviceUID);
            outputDeviceUID = copyDefaultProxyOutputDeviceUID();
        }
        setupTargetOutputDevice();
    });
    return noErr;
}''',1)
s=s.replace('    value = std::max(value, kOutputDeviceMinBufferFrameSize);', '    value = std::clamp(value, 32, 4096);')
s=s.replace('    if (newSize <= 0 || newSize > INT32_MAX)', '    if (newSize < 32 || newSize > 4096)')
# Restore the native volume and mute across coreaudiod / machine restarts.
s=s.replace('    deviceName = copyDeviceNameFromStorage();', '''    for (int channel = 0; channel < 2; ++channel) {
        CFPropertyListRef saved = nullptr;
        gPlugIn_Host->CopyFromStorage(gPlugIn_Host, channel == 0 ? CFSTR("volumeL") : CFSTR("volumeR"), &saved);
        Float32 value = 0.5f;
        if (saved && CFGetTypeID(saved) == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)saved, kCFNumberFloat32Type, &value);
        if (saved) CFRelease(saved);
        if (!std::isfinite(value)) value = 0.5f;
        (channel == 0 ? gVolume_Output_L_Value : gVolume_Output_R_Value) = std::clamp(value, 0.0f, 1.0f);
    }
    CFPropertyListRef savedMute = nullptr;
    gPlugIn_Host->CopyFromStorage(gPlugIn_Host, CFSTR("mute"), &savedMute);
    if (savedMute && CFGetTypeID(savedMute) == CFBooleanGetTypeID()) gMute_Output_Mute = CFBooleanGetValue((CFBooleanRef)savedMute);
    if (savedMute) CFRelease(savedMute);
    deviceName = copyDeviceNameFromStorage();''')
s=s.replace('#include <algorithm>','#include <algorithm>\n#include <cmath>')
a=s.index('OSStatus ProxyAudioDevice::SetControlPropertyData(')
b=s.index('#pragma mark Output Device Operations',a)
part=s[a:b].replace('Done:\n    return theAnswer;', 'Done:\n    if (theAnswer == noErr && *outNumberPropertiesChanged > 0) persistVolume();\n    return theAnswer;')
# Reject NaN/Inf before any gain can reach the real-time audio path.
part=part.replace('                    theNewVolume = *((const Float32 *)inData);','''                    theNewVolume = *((const Float32 *)inData);
                    FailWithAction(!std::isfinite(theNewVolume), theAnswer = kAudioHardwareIllegalOperationError, Done, "non-finite volume");''')
s=s[:a]+part+s[b:]
a=s.index('void ProxyAudioDevice::calculateVolumeFactors(')
b=s.index('\nOSStatus ProxyAudioDevice::EndIOOperation',a)
s=s[:a]+'''void ProxyAudioDevice::persistVolume() {
    UInt64 generation = ++volumeStorageGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC), AudioOutputDispatchQueue(), ^{
        if (generation != volumeStorageGeneration.load()) return;
        Float32 left, right;
        bool mute;
        { CAMutex::Locker locker(stateMutex); left = gVolume_Output_L_Value; right = gVolume_Output_R_Value; mute = gMute_Output_Mute; }
        CFNumberRef l = CFNumberCreate(NULL, kCFNumberFloat32Type, &left);
        CFNumberRef r = CFNumberCreate(NULL, kCFNumberFloat32Type, &right);
        gPlugIn_Host->WriteToStorage(gPlugIn_Host, CFSTR("volumeL"), l);
        gPlugIn_Host->WriteToStorage(gPlugIn_Host, CFSTR("volumeR"), r);
        gPlugIn_Host->WriteToStorage(gPlugIn_Host, CFSTR("mute"), mute ? kCFBooleanTrue : kCFBooleanFalse);
        CFRelease(l); CFRelease(r);
    });
}

void ProxyAudioDevice::calculateVolumeFactors(Float32 volumeL, Float32 volumeR, bool mute,
                                              Float32 &volumeFactorL, Float32 &volumeFactorR) {
    auto gain = [this, mute](Float32 value) -> Float32 {
        if (mute || !std::isfinite(value) || value <= 0) return 0;
        if (value >= 1) return 1;
        // Match the dB value exposed to HAL: voltage/amplitude is 20*log10(gain).
        Float32 db = kVolume_MinDB + value * value * (kVolume_MaxDB - kVolume_MinDB);
        return std::pow(10.0f, db / 20.0f);
    };
    volumeFactorL = gain(volumeL);
    volumeFactorR = gain(volumeR);
}
'''+s[b:]
s=s.replace('inputBuffer->Fetch(workBuffer, currentOutputDeviceBufferFrameSize,', 'inputBuffer->Fetch(workBuffer, framesThisCycle,')
s=s.replace('    bool overrun = inputBuffer->Fetch(', '''    if (framesThisCycle > kDevice_RingBufferSize * 2) return noErr;
    bool overrun = inputBuffer->Fetch(''')
s=s.replace('    for (UInt32 bufferIndex = 0; bufferIndex < outOutputData->mNumberBuffers; bufferIndex++) {\n        UInt32 outputChannelCount', '    UInt32 firstChannel = 0;\n    for (UInt32 bufferIndex = 0; bufferIndex < outOutputData->mNumberBuffers; bufferIndex++) {\n        UInt32 outputChannelCount')
s=s.replace('std::min(outputChannelCount, currentInputDeviceChannelCount);','std::min(outputChannelCount, currentInputDeviceChannelCount > firstChannel ? currentInputDeviceChannelCount - firstChannel : 0);')
s=s.replace('(Float32 *)workBuffer + channelIndex;', '(Float32 *)workBuffer + firstChannel + channelIndex;')
s=s.replace('((channelIndex == 0) ? volumeFactorL : volumeFactorR)', '((firstChannel + channelIndex == 0) ? volumeFactorL : volumeFactorR)')
s=s.replace('''                out += outputChannelCount;
            }
        }
    }

    return noErr;''','''                out += outputChannelCount;
            }
        }
        firstChannel += outputChannelCount;
    }

    return noErr;''',1)
p.write_text(s)
# A typed custom HAL property replaces upstream's identify/name configurator protocol.
s=p.read_text()
def inject(signature, code):
    global s
    a=s.index(signature)
    a=s.index('{',a)+1
    s=s[:a]+'\n'+code+'\n'+s[a:]
inject('Boolean ProxyAudioDevice::HasProperty(', '''    if (inObjectID == kObjectID_Device && inAddress &&
        (inAddress->mSelector == 'tuid' || inAddress->mSelector == kAudioObjectPropertyCustomPropertyInfoList)) return true;''')
inject('OSStatus ProxyAudioDevice::IsPropertySettable(', '''    if (inObjectID == kObjectID_Device && inAddress && outIsSettable &&
        (inAddress->mSelector == 'tuid' || inAddress->mSelector == kAudioObjectPropertyCustomPropertyInfoList)) {
        *outIsSettable = inAddress->mSelector == 'tuid'; return noErr;
    }''')
inject('OSStatus ProxyAudioDevice::GetPropertyDataSize(', '''    if (inObjectID == kObjectID_Device && inAddress && outDataSize) {
        if (inAddress->mSelector == 'tuid') { *outDataSize = sizeof(CFStringRef); return noErr; }
        if (inAddress->mSelector == kAudioObjectPropertyCustomPropertyInfoList) { *outDataSize = sizeof(AudioServerPlugInCustomPropertyInfo); return noErr; }
    }''')
inject('OSStatus ProxyAudioDevice::GetPropertyData(', '''    if (inObjectID == kObjectID_Device && inAddress && outData && outDataSize) {
        if (inAddress->mSelector == 'tuid') {
            if (inDataSize < sizeof(CFStringRef)) return kAudioHardwareBadPropertySizeError;
            CAMutex::Locker locker(stateMutex);
            *(CFStringRef*)outData = CFStringCreateCopy(NULL, outputDeviceUID ? outputDeviceUID : CFSTR(""));
            *outDataSize = sizeof(CFStringRef); return noErr;
        }
        if (inAddress->mSelector == kAudioObjectPropertyCustomPropertyInfoList) {
            if (inDataSize < sizeof(AudioServerPlugInCustomPropertyInfo)) return kAudioHardwareBadPropertySizeError;
            *(AudioServerPlugInCustomPropertyInfo*)outData = {'tuid', kAudioServerPlugInCustomPropertyDataTypeCFString, kAudioServerPlugInCustomPropertyDataTypeNone};
            *outDataSize = sizeof(AudioServerPlugInCustomPropertyInfo); return noErr;
        }
    }''')
inject('OSStatus ProxyAudioDevice::SetPropertyData(', '''    if (inObjectID == kObjectID_Device && inAddress && inAddress->mSelector == 'tuid') {
        if (!inData || inDataSize != sizeof(CFStringRef)) return kAudioHardwareBadPropertySizeError;
        CFStringRef uid = *(CFStringRef*)inData;
        if (!uid || CFGetTypeID(uid) != CFStringGetTypeID() || CFStringGetLength(uid) > 512 ||
            CFStringCompare(uid, CFSTR(kDevice_UID), 0) == kCFCompareEqualTo) return kAudioHardwareIllegalOperationError;
        setOutputDevice(uid);
        gPlugIn_Host->PropertiesChanged(gPlugIn_Host, kObjectID_Device, 1, inAddress);
        return noErr;
    }''')
p.write_text(s)
# Publish disappearance to HAL so the OS can choose another output after unplugging.
s=p.read_text()
a=s.index('        case kAudioDevicePropertyDeviceIsAlive:',s.index('OSStatus ProxyAudioDevice::GetDevicePropertyData('))
b=s.index('        case kAudioDevicePropertyDeviceIsRunning:',a)
s=s[:a]+s[a:b].replace('*((UInt32 *)outData) = 1;', '*((UInt32 *)outData) = outputDeviceReady.load() ? 1 : 0;')+s[b:]
s=s.replace('''        gPlugIn_Host->PropertiesChanged(gPlugIn_Host, kObjectID_Device, 1, &theAddress);
    });
}

#pragma mark Other stuff!''', '''        AudioObjectPropertyAddress changes[] = {
            theAddress,
            { kAudioDevicePropertyDeviceIsAlive, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain }
        };
        gPlugIn_Host->PropertiesChanged(gPlugIn_Host, kObjectID_Device, 2, changes);
    });
}

#pragma mark Other stuff!''')
s=s.replace('''        outputDevice.stop();
        outputDeviceReady = false;''', '''        AudioObjectPropertyAddress alive = {kAudioDevicePropertyDeviceIsAlive, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
        AudioObjectPropertyAddress rate = {kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
        AudioObjectRemovePropertyListener(outputDevice.id, &alive, outputDeviceAliveListenerStatic, this);
        AudioObjectRemovePropertyListener(outputDevice.id, &rate, outputDeviceSampleRateListenerStatic, this);
        outputDevice.stop();
        outputDeviceReady = false;''')
p.write_text(s)
s=h.read_text().replace('    bool outputDeviceReady = false;', '    std::atomic_bool outputDeviceReady{false};')
h.write_text(s)
# Read-only diagnostics let validation measure the forwarded PCM without recording audio.
s=h.read_text().replace('    std::atomic<UInt64> volumeStorageGeneration{0};', '''    std::atomic<UInt64> volumeStorageGeneration{0};
    std::atomic<UInt64> renderedFrames{0}, sourceFrames{0}, underrunCount{0};
    std::atomic<Float32> renderedPeakL{0}, renderedPeakR{0};
    Float32 previousGainL = 0, previousGainR = 0;''')
h.write_text(s)
s=p.read_text()
s=s.replace("inAddress->mSelector == 'tuid' || inAddress->mSelector == kAudioObjectPropertyCustomPropertyInfoList", "inAddress->mSelector == 'tuid' || inAddress->mSelector == 'tmet' || inAddress->mSelector == kAudioObjectPropertyCustomPropertyInfoList")
s=s.replace("if (inAddress->mSelector == 'tuid') { *outDataSize = sizeof(CFStringRef); return noErr; }", "if (inAddress->mSelector == 'tuid' || inAddress->mSelector == 'tmet') { *outDataSize = sizeof(CFTypeRef); return noErr; }")
s=s.replace('*outDataSize = sizeof(AudioServerPlugInCustomPropertyInfo); return noErr;', '*outDataSize = sizeof(AudioServerPlugInCustomPropertyInfo) * 2; return noErr;',1)
s=s.replace('if (inDataSize < sizeof(AudioServerPlugInCustomPropertyInfo)) return kAudioHardwareBadPropertySizeError;', 'if (inDataSize < sizeof(AudioServerPlugInCustomPropertyInfo) * 2) return kAudioHardwareBadPropertySizeError;',1)
s=s.replace("*outDataSize = sizeof(AudioServerPlugInCustomPropertyInfo); return noErr;", "((AudioServerPlugInCustomPropertyInfo*)outData)[1] = {'tmet', kAudioServerPlugInCustomPropertyDataTypeCFPropertyList, kAudioServerPlugInCustomPropertyDataTypeNone};\n            *outDataSize = sizeof(AudioServerPlugInCustomPropertyInfo) * 2; return noErr;",1)
a=s.index("        if (inAddress->mSelector == 'tuid') {",s.index('OSStatus ProxyAudioDevice::GetPropertyData('))
s=s[:a]+'''        if (inAddress->mSelector == 'tmet') {
            if (inDataSize < sizeof(CFDictionaryRef)) return kAudioHardwareBadPropertySizeError;
            const void *keys[] = {CFSTR("renderedFrames"), CFSTR("sourceFrames"), CFSTR("underruns"), CFSTR("peakL"), CFSTR("peakR")};
            SInt64 frames = renderedFrames.load(), source = sourceFrames.load(), misses = underrunCount.load();
            Float32 l = renderedPeakL.load(), r = renderedPeakR.load();
            CFNumberRef values[] = {
                CFNumberCreate(NULL, kCFNumberSInt64Type, &frames), CFNumberCreate(NULL, kCFNumberSInt64Type, &source),
                CFNumberCreate(NULL, kCFNumberSInt64Type, &misses), CFNumberCreate(NULL, kCFNumberFloat32Type, &l), CFNumberCreate(NULL, kCFNumberFloat32Type, &r)
            };
            *(CFDictionaryRef*)outData = CFDictionaryCreate(NULL, keys, (const void**)values, 5, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            for (auto value : values) CFRelease(value);
            *outDataSize = sizeof(CFDictionaryRef); return noErr;
        }
'''+s[a:]
s=s.replace('''            lastInputFrameTime = inputSampleTime;''', '''            sourceFrames.fetch_add(inIOBufferFrameSize, std::memory_order_relaxed);
            lastInputFrameTime = inputSampleTime;''',1)
s=s.replace('''    bool overrun = inputBuffer->Fetch(workBuffer, framesThisCycle, (SInt64)startFrame);''','''    bool overrun = inputBuffer->Fetch(workBuffer, framesThisCycle, (SInt64)startFrame);
    if (overrun) underrunCount.fetch_add(1, std::memory_order_relaxed);''',1)
s=s.replace('    UInt32 firstChannel = 0;', '    Float32 peakL = 0, peakR = 0;\n    UInt32 firstChannel = 0;',1)
s=s.replace('''                *out += (*in * ((firstChannel + channelIndex == 0) ? volumeFactorL : volumeFactorR));''','''                bool isLeft = firstChannel + channelIndex == 0;
                Float32 targetGain = isLeft ? volumeFactorL : volumeFactorR;
                Float32 previousGain = isLeft ? previousGainL : previousGainR;
                Float32 ramp = std::min(1.0f, (Float32)(frame / framesize + 1) / 64.0f);
                Float32 gain = previousGain + (targetGain - previousGain) * ramp;
                Float32 sample = *in * gain;
                *out += sample;
                if (isLeft) peakL = std::max(peakL, std::abs(sample));
                else peakR = std::max(peakR, std::abs(sample));''',1)
s=s.replace('''        firstChannel += outputChannelCount;
    }

    return noErr;''','''        firstChannel += outputChannelCount;
    }
    previousGainL = volumeFactorL; previousGainR = volumeFactorR;
    renderedFrames.fetch_add(framesThisCycle, std::memory_order_relaxed);
    renderedPeakL.store(peakL, std::memory_order_relaxed);
    renderedPeakR.store(peakR, std::memory_order_relaxed);
    return noErr;''',1)
p.write_text(s)
# Keep initialization / discovery races out of the HAL property thread.
s=p.read_text()
s=s.replace('''    static ProxyAudioDevice *mainDevice = nullptr;

    if (!mainDevice) {
        mainDevice = new ProxyAudioDevice;
    }''', '''    static ProxyAudioDevice *mainDevice = new ProxyAudioDevice;''')
s=s.replace('    CFStringGetCString(s, buffer, length, kCFStringEncodingUTF8);', '    if (!CFStringGetCString(s, buffer, length, kCFStringEncodingUTF8)) { delete[] buffer; return std::string(); }')
s=s.replace('''                       if (!outputDeviceUID) {
                           outputDeviceUID = copyDefaultProxyOutputDeviceUID();
                       }''', '''                       bool needsTarget;
                       { CAMutex::Locker locker(stateMutex); needsTarget = !outputDeviceUID; }
                       if (needsTarget) {
                           CFStringRef candidate = copyDefaultProxyOutputDeviceUID();
                           CAMutex::Locker locker(stateMutex);
                           if (!outputDeviceUID) outputDeviceUID = candidate;
                           else CFRelease(candidate);
                       }''')
s=s.replace('''        if (!outputDeviceUID || CFStringGetLength(outputDeviceUID) == 0) {
            if (outputDeviceUID) CFRelease(outputDeviceUID);
            outputDeviceUID = copyDefaultProxyOutputDeviceUID();
        }''','''        bool needsTarget;
        { CAMutex::Locker locker(stateMutex); needsTarget = !outputDeviceUID || CFStringGetLength(outputDeviceUID) == 0; }
        if (needsTarget) {
            CFStringRef candidate = copyDefaultProxyOutputDeviceUID();
            CAMutex::Locker locker(stateMutex);
            if (!outputDeviceUID || CFStringGetLength(outputDeviceUID) == 0) {
                if (outputDeviceUID) CFRelease(outputDeviceUID);
                outputDeviceUID = candidate;
            } else CFRelease(candidate);
        }''')
p.write_text(s)
# A perceptual software curve with useful low levels: gain = scalar², never amplification.
s=h.read_text().replace('kVolume_MinDB = -25.0', 'kVolume_MinDB = -96.0')
h.write_text(s)
s=p.read_text()
pos=s.index('#pragma mark Utility Functions')
s=s[:pos]+'''static Float32 TitanScalarToDB(Float32 scalar) {
    if (!std::isfinite(scalar) || scalar <= 0) return -96.0f;
    return std::max(-96.0f, 40.0f * std::log10(std::min(scalar, 1.0f)));
}
static Float32 TitanDBToScalar(Float32 db) {
    if (!std::isfinite(db) || db <= -96.0f) return 0;
    return std::pow(10.0f, std::min(db, 0.0f) / 40.0f);
}

'''+s[pos:]
s=s.replace('''                    *((Float32 *)outData) *= *((Float32 *)outData);
                    *((Float32 *)outData) = kVolume_MinDB + (*((Float32 *)outData) * (kVolume_MaxDB - kVolume_MinDB));''', '''                    *((Float32 *)outData) = TitanScalarToDB(*((Float32 *)outData));''')
s=s.replace('''                    *((Float32 *)outData) = *((Float32 *)outData) - kVolume_MinDB;
                    *((Float32 *)outData) /= kVolume_MaxDB - kVolume_MinDB;
                    *((Float32 *)outData) = sqrtf(*((Float32 *)outData));''', '''                    *((Float32 *)outData) = TitanDBToScalar(*((Float32 *)outData));''')
s=s.replace('''                    theNewVolume = theNewVolume - kVolume_MinDB;
                    theNewVolume /= kVolume_MaxDB - kVolume_MinDB;
                    theNewVolume = sqrtf(theNewVolume);''', '''                    theNewVolume = TitanDBToScalar(theNewVolume);''')
s=s.replace('''        Float32 db = kVolume_MinDB + value * value * (kVolume_MaxDB - kVolume_MinDB);
        return std::pow(10.0f, db / 20.0f);''', '''        return value * value;''')
p.write_text(s)
