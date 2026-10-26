import AppKit
import Combine
import CoreAudio
import TitanArmyCore

@MainActor
final class SystemAudioModel: ObservableObject {
    @Published private(set) var devices: [AudioEndpoint] = []
    @Published private(set) var currentOutput: AudioEndpoint?
    @Published private(set) var proxy: AudioEndpoint?
    @Published private(set) var targetUID: String?
    @Published private(set) var isMuted = false
    @Published private(set) var isWorking = false
    @Published private(set) var isInstalled = false
    @Published var volumeDraft: Double = 50
    @Published var failure: String?

    private var selectedName: String?
    private var isEditingVolume = false
    private var observation: AudioPropertyObservation?
    private var observedIDs: [UInt32] = []
    private var refreshPending = false
    private var handledLaunchRequest = false
    private var language: AppLanguage = .systemDefault
    private let installedPath = "/Library/Audio/Plug-Ins/HAL/TitanArmyAudio.driver"

    var selectedEndpoint: AudioEndpoint? {
        guard let selectedName else { return nil }
        return try? SystemAudio.matchingDisplay(selectedName, in: devices)
    }
    var usesSystemVolume: Bool {
        guard let proxy, proxy.isAlive, let selectedEndpoint else { return false }
        return targetUID == selectedEndpoint.uid
    }
    var isDefaultOutput: Bool { usesSystemVolume && currentOutput?.id == proxy?.id }

    init() { refresh() }

    func handleLaunchRequest() {
        guard !handledLaunchRequest else { return }
        handledLaunchRequest = true
        if CommandLine.arguments.contains("--install-system-audio") { install() }
    }

    func setDisplay(_ name: String?, language: AppLanguage) {
        selectedName = name
        self.language = language
        refresh()
    }

    func refresh() {
        devices = SystemAudio.endpoints()
        proxy = devices.first(where: \.isTitanArmyAudio)
        currentOutput = devices.first { $0.id == SystemAudio.defaultOutputID() }
        targetUID = proxy.flatMap { SystemAudio.targetUID($0.id) }
        isInstalled = FileManager.default.fileExists(atPath: installedPath)
        if let proxy {
            isMuted = SystemAudio.muted(proxy.id)
            if !isEditingVolume, let volume = SystemAudio.volume(proxy.id) { volumeDraft = Double(volume) * 100 }
        }
        let ids = devices.map(\.id).sorted()
        if ids != observedIDs || observation == nil { attachObservers(ids) }
    }

    private func attachObservers(_ ids: [UInt32]) {
        observedIDs = ids
        var properties: [(AudioObjectID, AudioObjectPropertyAddress)] = [
            (AudioObjectID(kAudioObjectSystemObject), SystemAudio.address(kAudioHardwarePropertyDevices)),
            (AudioObjectID(kAudioObjectSystemObject), SystemAudio.address(kAudioHardwarePropertyDefaultOutputDevice)),
            (AudioObjectID(kAudioObjectSystemObject), SystemAudio.address(kAudioHardwarePropertyDefaultSystemOutputDevice)),
        ]
        if let proxy {
            properties.append((proxy.id, SystemAudio.address(SystemAudio.targetUIDSelector)))
            properties.append((proxy.id, SystemAudio.address(kAudioDevicePropertyDeviceIsAlive)))
            properties.append((proxy.id, SystemAudio.address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeOutput)))
            for channel: UInt32 in 0...2 {
                properties.append((proxy.id, SystemAudio.address(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput, element: channel)))
            }
        }
        observation = AudioPropertyObservation(objects: properties) { [weak self] in
            Task { @MainActor [weak self] in self?.scheduleRefresh() }
        }
    }

    private func scheduleRefresh() {
        guard !refreshPending else { return }
        refreshPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self else { return }
            self.refreshPending = false
            self.refresh()
        }
    }

    func previewVolume(_ value: Double) {
        guard let proxy, usesSystemVolume else { return }
        isEditingVolume = true
        volumeDraft = value
        do { try SystemAudio.setVolume(Float(value / 100), on: proxy.id) }
        catch { show(error) }
    }

    func commitVolume() {
        isEditingVolume = false
        refresh()
    }

    func toggleMute() {
        guard let proxy else { return }
        do { try SystemAudio.setMuted(!isMuted, on: proxy.id); refresh() }
        catch { show(error) }
    }

    func activate() {
        guard !isWorking else { return }
        isWorking = true
        failure = nil
        Task {
            defer { isWorking = false; refresh() }
            do { try await connectDisplay() } catch { show(error) }
        }
    }

    private func connectDisplay() async throws {
        refresh()
        guard let selectedName else { throw AudioRoutingError.displayAudioMissing }
        let target = try SystemAudio.matchingDisplay(selectedName, in: devices)
        guard let proxy else { throw AudioRoutingError.driverMissing }
        try SystemAudio.setTargetUID(target.uid, on: proxy.id)
        for _ in 0..<50 {
            if SystemAudio.uint(proxy.id, kAudioDevicePropertyDeviceIsAlive) == 1 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard SystemAudio.uint(proxy.id, kAudioDevicePropertyDeviceIsAlive) == 1 else { throw AudioRoutingError.routeNotReady }
        try SystemAudio.enable(for: target)
    }

    func disable() {
        do { try SystemAudio.disable(); refresh() } catch { show(error) }
    }

    func install() {
        guard !isWorking else { return }
        isWorking = true
        failure = nil
        Task {
            defer { isWorking = false; refresh() }
            do {
                try await runInstaller(action: "install")
                for _ in 0..<100 {
                    refresh()
                    if proxy != nil { break }
                    try await Task.sleep(for: .milliseconds(100))
                }
                try await connectDisplay()
            } catch { show(error) }
        }
    }

    func uninstall() {
        guard !isWorking else { return }
        isWorking = true
        failure = nil
        Task {
            defer { isWorking = false; refresh() }
            do {
                try SystemAudio.disable()
                try await runInstaller(action: "uninstall")
            } catch { show(error) }
        }
    }

    private func runInstaller(action: String) async throws {
        guard let resources = Bundle.main.resourceURL else { throw AudioRoutingError.driverMissing }
        let script = resources.appendingPathComponent("install-audio.sh").path
        let driver = resources.appendingPathComponent("TitanArmyAudio.driver").path
        guard FileManager.default.fileExists(atPath: script) else { throw AudioRoutingError.driverMissing }
        func shellQuote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let command = "/bin/bash \(shellQuote(script)) \(shellQuote(action)) \(shellQuote(driver))"
        func appleScriptQuote(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let l10n = L10n(language: language)
        let prompt = action == "uninstall"
            ? l10n.pick("Titan Army 需要移除显示器的系统音量组件。", "Titan Army needs to remove the display’s system volume component.")
            : l10n.pick("Titan Army 需要安装显示器的系统音量组件。", "Titan Army needs to install the display’s system volume component.")
        let appleScript = "do shell script \(appleScriptQuote(command)) with administrator privileges with prompt \(appleScriptQuote(prompt))"
        try await Task.detached(priority: .userInitiated) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", appleScript]
            let pipe = Pipe()
            task.standardError = pipe
            task.standardOutput = FileHandle.nullDevice
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                throw NSError(domain: "TitanArmyAudioInstaller", code: Int(task.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)])
            }
        }.value
    }

    private func show(_ error: Error) {
        let l10n = L10n(language: language)
        switch error {
        case AudioRoutingError.driverMissing:
            failure = l10n.pick("请先安装系统音量组件。", "Install the system volume component first.")
        case AudioRoutingError.displayAudioMissing, AudioRoutingError.ambiguousDisplayAudio:
            failure = l10n.pick("未能唯一匹配显示器的声音输出，请检查显示器连接后重试。", "Could not uniquely match the display’s audio output. Check the connection and try again.")
        case AudioRoutingError.routeNotReady:
            failure = l10n.pick("音频组件正在连接显示器，请稍后重试。", "The audio component is connecting to your display. Try again shortly.")
        default:
            if error.localizedDescription.contains("-128") {
                failure = l10n.pick("安装已取消。", "Installation cancelled.")
            } else {
                failure = l10n.pick("无法完成音频设置：", "Could not complete audio setup: ") + error.localizedDescription
            }
        }
    }
}
