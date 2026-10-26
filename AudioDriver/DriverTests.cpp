#include "ProxyAudioDevice.h"
#include "AudioRingBuffer.h"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <limits>
#include <string>
#include <vector>
#include <dispatch/dispatch.h>

static CFMutableDictionaryRef storage;
static OSStatus changed(AudioServerPlugInHostRef, AudioObjectID, UInt32, const AudioObjectPropertyAddress*) { return noErr; }
static OSStatus copyStored(AudioServerPlugInHostRef, CFStringRef key, CFPropertyListRef* value) {
    auto found = CFDictionaryGetValue(storage, key);
    *value = found ? CFRetain(found) : nullptr;
    return noErr;
}
static OSStatus writeStored(AudioServerPlugInHostRef, CFStringRef key, CFPropertyListRef value) {
    CFDictionarySetValue(storage, key, value); return noErr;
}
static OSStatus deleteStored(AudioServerPlugInHostRef, CFStringRef key) { CFDictionaryRemoveValue(storage,key); return noErr; }
static OSStatus configuration(AudioServerPlugInHostRef, AudioObjectID, UInt64, void*) { return noErr; }
static AudioServerPlugInHostInterface host = {changed, copyStored, writeStored, deleteStored, configuration};
static int checks = 0;
static void require(bool result) { assert(result); ++checks; }
extern std::string CFStringToStdString(CFStringRef);

int main() {
    storage = CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(storage, CFSTR("deviceName"), CFSTR("Titan Army Audio"));
    float initial = .4f;
    CFNumberRef initialNumber = CFNumberCreate(nullptr, kCFNumberFloat32Type, &initial);
    CFDictionarySetValue(storage, CFSTR("volumeL"), initialNumber);
    CFRelease(initialNumber);
    auto driver = (AudioServerPlugInDriverRef)TitanArmyAudio_Create(nullptr, kAudioServerPlugInTypeUUID);
    require(driver != nullptr);
    require((*driver)->Initialize(driver, &host) == noErr);
    auto device = ProxyAudioDevice::deviceForDriver(driver);
    require(std::abs(device->gVolume_Output_L_Value - .4f) < 1e-6);
    require(std::abs(device->gVolume_Output_R_Value - .5f) < 1e-6);
    require(CFStringToStdString(CFSTR("显示器・音量🎵")) == "显示器・音量🎵");

    auto scalar = AudioObjectPropertyAddress{kAudioLevelControlPropertyScalarValue,kAudioObjectPropertyScopeGlobal,0};
    auto boolean = AudioObjectPropertyAddress{kAudioBooleanControlPropertyValue,kAudioObjectPropertyScopeGlobal,0};
    auto setScalar = [&](AudioObjectID control, float value) {
        return (*driver)->SetPropertyData(driver,control,getpid(),&scalar,0,nullptr,sizeof(value),&value);
    };
    require(setScalar(kObjectID_Volume_Output_L, std::numeric_limits<float>::quiet_NaN()) != noErr);
    require(setScalar(kObjectID_Volume_Output_L, std::numeric_limits<float>::infinity()) != noErr);
    require(setScalar(kObjectID_Volume_Output_L, -.4f) == noErr);
    require(device->gVolume_Output_L_Value == 0);
    require(setScalar(kObjectID_Volume_Output_L, 1.4f) == noErr);
    require(device->gVolume_Output_L_Value == 1);
    require(setScalar(kObjectID_Volume_Output_L, .5f) == noErr);
    require(setScalar(kObjectID_Volume_Output_R, 1.f) == noErr);

    float left, right;
    device->calculateVolumeFactors(.5f,1,false,left,right);
    require(std::abs(left - .25f) < 1e-6);
    require(right == 1);
    auto dbAddress = AudioObjectPropertyAddress{kAudioLevelControlPropertyDecibelValue,kAudioObjectPropertyScopeGlobal,0};
    float dbValue=0; UInt32 dbSize=0;
    require((*driver)->GetPropertyData(driver,kObjectID_Volume_Output_L,getpid(),&dbAddress,0,nullptr,sizeof(dbValue),&dbSize,&dbValue)==noErr);
    require(std::abs(std::pow(10.f,dbValue/20.f)-left)<1e-6);
    auto convert = AudioObjectPropertyAddress{kAudioLevelControlPropertyConvertDecibelsToScalar,kAudioObjectPropertyScopeGlobal,0};
    require((*driver)->GetPropertyData(driver,kObjectID_Volume_Output_L,getpid(),&convert,0,nullptr,sizeof(dbValue),&dbSize,&dbValue)==noErr);
    require(std::abs(dbValue-.5f)<1e-6);
    device->calculateVolumeFactors(.01f,.01f,false,left,right);
    require(std::abs(left-.0001f)<1e-8);
    device->calculateVolumeFactors(0,0,false,left,right);
    require(left == 0 && right == 0);
    device->calculateVolumeFactors(1,1,true,left,right);
    require(left == 0 && right == 0);

    auto target = AudioObjectPropertyAddress{'tuid',kAudioObjectPropertyScopeGlobal,0};
    auto custom = AudioObjectPropertyAddress{kAudioObjectPropertyCustomPropertyInfoList,kAudioObjectPropertyScopeGlobal,0};
    require((*driver)->HasProperty(driver,kObjectID_Device,getpid(),&target));
    UInt32 size=0;
    require((*driver)->GetPropertyDataSize(driver,kObjectID_Device,getpid(),&custom,0,nullptr,&size)==noErr);
    require(size==sizeof(AudioServerPlugInCustomPropertyInfo)*2);
    AudioServerPlugInCustomPropertyInfo info[2];
    require((*driver)->GetPropertyData(driver,kObjectID_Device,getpid(),&custom,0,nullptr,sizeof(info),&size,&info)==noErr);
    require(info[0].mSelector == 'tuid' && info[0].mPropertyDataType == kAudioServerPlugInCustomPropertyDataTypeCFString);
    CFStringRef ownUID = CFSTR(kDevice_UID);
    require((*driver)->SetPropertyData(driver,kObjectID_Device,getpid(),&target,0,nullptr,sizeof(ownUID),&ownUID) != noErr);

    device->outputDevice.sampleRate = 48000;
    device->outputDevice.safetyOffset = 0;
    device->outputDevice.bufferFrameSize = 512;
    for (UInt32 frames : {256u,512u,1024u}) {
        std::vector<float> input(frames*2);
        for (UInt32 i=0;i<frames;++i) { input[2*i]=.25f; input[2*i+1]=.75f; }
        device->inputBuffer->Clear();
        device->inputBuffer->Store((Byte*)input.data(),frames,1000);
        device->lastInputFrameTime = 1000;
        device->lastInputBufferFrameSize = frames;
        device->inputOutputSampleDeltaValid = true;
        device->inputOutputSampleDelta = 0;
        device->expectedOutputSampleTime = -1;
        AudioTimeStamp time = {}; time.mSampleTime = 1000;
        std::vector<float> interleaved(frames*2);
        AudioBufferList inter = {1,{{2,UInt32(interleaved.size()*sizeof(float)),interleaved.data()}}};
        require(device->outputDeviceIOProc(0,&time,nullptr,&time,&inter,&time) == noErr);
        device->calculateVolumeFactors(.5f,1,false,left,right);
        require(std::abs(interleaved[interleaved.size()-2] - .25f*left) < 1e-6);
        require(std::abs(interleaved.back() - .75f) < 1e-6);
        std::vector<float> l(frames),r(frames);
        struct { UInt32 count; AudioBuffer buffers[2]; } planar = {2,{{1,frames*4,l.data()},{1,frames*4,r.data()}}};
        device->expectedOutputSampleTime = -1;
        require(device->outputDeviceIOProc(0,&time,nullptr,&time,(AudioBufferList*)&planar,&time) == noErr);
        require(std::abs(l.back() - .25f*left) < 1e-6);
        require(std::abs(r.back() - .75f) < 1e-6);
        UInt32 muted=1;
        require((*driver)->SetPropertyData(driver,kObjectID_Mute_Output_Master,getpid(),&boolean,0,nullptr,sizeof(muted),&muted)==noErr);
        std::fill(interleaved.begin(),interleaved.end(),0);
        device->expectedOutputSampleTime = -1;
        require(device->outputDeviceIOProc(0,&time,nullptr,&time,&inter,&time) == noErr);
        require(interleaved.back()==0 && interleaved[interleaved.size()-2]==0);
        std::fill(interleaved.begin(),interleaved.end(),0);
        device->expectedOutputSampleTime = -1;
        require(device->outputDeviceIOProc(0,&time,nullptr,&time,&inter,&time) == noErr);
        require(std::all_of(interleaved.begin(),interleaved.end(),[](float x){return x==0;}));
        muted=0;
        require((*driver)->SetPropertyData(driver,kObjectID_Mute_Output_Master,getpid(),&boolean,0,nullptr,sizeof(muted),&muted)==noErr);
    }
    auto meters = AudioObjectPropertyAddress{'tmet',kAudioObjectPropertyScopeGlobal,0};
    CFDictionaryRef stats = nullptr;
    require((*driver)->GetPropertyData(driver,kObjectID_Device,getpid(),&meters,0,nullptr,sizeof(stats),&size,&stats)==noErr);
    require(stats && CFDictionaryContainsKey(stats,CFSTR("renderedFrames")));
    SInt64 rendered=0;
    CFNumberGetValue((CFNumberRef)CFDictionaryGetValue(stats,CFSTR("renderedFrames")),kCFNumberSInt64Type,&rendered);
    require(rendered > 0);
    CFRelease(stats);
    // Dispatch queue barrier verifies that coalesced persistence has reached storage.
    usleep(220000);
    dispatch_sync(device->AudioOutputDispatchQueue(), ^{});
    auto persisted = (CFNumberRef)CFDictionaryGetValue(storage, CFSTR("volumeL"));
    require(persisted != nullptr);
    float saved=0;
    CFNumberGetValue(persisted,kCFNumberFloat32Type,&saved);
    require(saved==.5f);
    require(CFDictionaryGetValue(storage,CFSTR("mute"))==kCFBooleanFalse);
    printf("Driver tests: %d checks passed (gain, mute, stereo layouts, varying buffers, persistence, typed properties).\n",checks);
    fflush(stdout);
    _Exit(0); // HAL owns the singleton for its process lifetime.
}
