import AppKit
import Combine
import Foundation
import TitanArmyCore

/// UI state and every side effect the interface can trigger.
///
/// All hardware work happens off the main thread; the published state is only
/// mutated on the main queue.
@MainActor
final class MonitorViewModel: ObservableObject {
    struct Notice: Identifiable, Equatable {
        enum Level { case info, warning, error }
        let id = UUID()
        let level: Level
        let text: String
    }

    @Published private(set) var displays: [DisplayDescriptor] = []
    @Published private(set) var controller: MonitorController?
    @Published private(set) var snapshot = DisplaySnapshot()
    @Published private(set) var isBusy = false
    @Published private(set) var selectedDisplayID: CGDirectDisplayID?
    @Published var notice: Notice?
    /// The HDR state the user just asked for, shown while the link retrains so
    /// the switch does not flip back to the old state for several seconds.
    @Published private(set) var pendingHDR: Bool?

    /// Slider positions, kept separate from the snapshot so dragging stays smooth
    /// and a rejected write visibly snaps back.
    @Published var brightnessDraft: Double = 100
    @Published var contrastDraft: Double = 50
    @Published var volumeDraft: Double = 100
    @Published var isEditingTone = false

    /// Kept in the view model so asynchronous hardware errors are localized at
    /// the moment they surface, not baked into an English string first.
    private var language: AppLanguage = .systemDefault
    private var l10n: L10n { L10n(language: language) }

    private let workQueue = DispatchQueue(label: "TitanArmy.hardware", qos: .userInitiated)
    private var observers: [NSObjectProtocol] = []

    var isHDREnabled: Bool { pendingHDR ?? (snapshot.hdrEnabled == true) }

    init(autostart: Bool = true) {
        if autostart { refresh(thorough: true) }
        // HDR can be switched outside the app (System Settings, Control
        // Center). Both notifications are cheap triggers for a re-check.
        for name in [NSApplication.didBecomeActiveNotification,
                     NSApplication.didChangeScreenParametersNotification] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncHDRState() }
            })
        }
    }

    /// Picks up HDR changes made elsewhere. The CoreDisplay query needs no DDC
    /// traffic; tone registers are re-read only after the link has retrained.
    func syncHDRState() {
        guard !isBusy, pendingHDR == nil, let controller else { return }
        let current = controller.hdrEnabled
        guard current != snapshot.hdrEnabled else { return }
        snapshot.hdrEnabled = current
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(CoreDisplayHDR.postSwitchSettleSeconds))
            guard let self, !self.isBusy, self.controller === controller else { return }
            self.isBusy = true
            self.workQueue.async { [weak self] in
                let fresh = controller.snapshot()
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.show(fresh)
                    self.isBusy = false
                }
            }
        }
    }

    // MARK: - Discovery

    func refresh(thorough: Bool = false, synchronous: Bool = false) {
        guard !isBusy else { return }
        isBusy = true
        notice = nil
        let targetID = selectedDisplayID

        let work: @Sendable () -> Void = { [weak self] in
            let found = DisplayDiscovery.onlineDisplays()
            let chosen = found.first { $0.id == targetID && targetID != nil }
                ?? found.first(where: { $0.isTargetModel })
                ?? found.first

            var connected: MonitorController?
            var snap = DisplaySnapshot()
            var failure: Error?
            var readsUnavailable = false

            if let chosen {
                if let candidate = MonitorController.connect(chosen) {
                    connected = candidate
                    snap = candidate.snapshot(thorough: thorough)
                    readsUnavailable = !snap.brightness.available && !snap.contrast.available && !snap.volume.available
                } else {
                    failure = MonitorController.Failure.noDDCChannel
                }
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.displays = found
                self.controller = connected
                self.snapshot = snap
                self.selectedDisplayID = chosen?.id
                self.brightnessDraft = snap.brightness.available ? Double(snap.brightness.value) : 100
                self.contrastDraft = snap.contrast.available ? Double(snap.contrast.value) : 50
                self.volumeDraft = snap.volume.available ? Double(snap.volume.value) : 100
                self.isBusy = false
                if let failure {
                    self.notice = Notice(level: .error, text: self.l10n.error(failure))
                } else if readsUnavailable {
                    self.notice = Notice(level: .warning, text: self.l10n.pick(
                        "显示器已连接，但暂时未返回控制数据。请稍后刷新重试。",
                        "The display is connected but is not returning control data. Refresh to try again."
                    ))
                }
            }
        }

        if synchronous {
            workQueue.sync(execute: work)
            // `work` already dispatched its UI update to the main queue; drain it.
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        } else {
            workQueue.async(execute: work)
        }
    }

    func select(_ descriptor: DisplayDescriptor) {
        guard !isBusy, descriptor.id != selectedDisplayID else { return }
        selectedDisplayID = descriptor.id
        refresh(thorough: true)
    }

    // MARK: - Tone

    /// Called continuously while dragging; never touches hardware.
    func previewBrightness(_ value: Double) {
        isEditingTone = true
        brightnessDraft = value
    }

    func previewContrast(_ value: Double) {
        isEditingTone = true
        contrastDraft = value
    }

    func commitBrightness() {
        commitTone(kind: .brightness, percent: Int(brightnessDraft.rounded()))
    }

    func commitContrast() {
        commitTone(kind: .contrast, percent: Int(contrastDraft.rounded()))
    }

    func previewVolume(_ value: Double) {
        isEditingTone = true
        volumeDraft = value
    }

    func commitVolume() {
        commitTone(kind: .volume, percent: Int(volumeDraft.rounded()))
    }

    private enum ToneKind { case brightness, contrast, volume }

    private func commitTone(kind: ToneKind, percent: Int) {
        guard let controller else { return }
        isBusy = true

        workQueue.async { [weak self] in
            var failure: Error?
            var level = Notice.Level.info
            do {
                switch kind {
                case .brightness: try controller.setBrightness(percent: percent)
                case .contrast: try controller.setContrast(percent: percent)
                case .volume: try controller.setVolume(percent: percent)
                }
            } catch let error as MonitorController.Failure
                where error == .toneLockedByHDR {
                failure = error
                level = .warning
            } catch {
                failure = error
                level = .error
            }

            let fresh = controller.snapshot()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isEditingTone = false
                // Reflect reality, even when the write was rejected.
                self.show(fresh)
                self.isBusy = false
                if let failure {
                    self.notice = Notice(level: level, text: self.l10n.error(failure))
                }
            }
        }
    }

    // MARK: - HDR

    func setSystemHDR(_ enabled: Bool) {
        guard let controller else { return }
        isBusy = true
        pendingHDR = enabled
        workQueue.async { [weak self] in
            let ok = controller.setSystemHDR(enabled: enabled)
            let fresh = controller.snapshot(thorough: true)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.show(fresh)
                self.pendingHDR = nil
                self.isBusy = false
                if !ok {
                    self.notice = Notice(
                        level: .error,
                        text: self.l10n.pick(
                            "macOS 未能确认 HDR 状态变化。",
                            "macOS did not confirm the HDR change."
                        )
                    )
                }
            }
        }
    }

    // MARK: - Vendor controls

    func setVendorHDR(_ mode: TitanArmyProfile.VendorHDR) {
        perform(l10n.pick("显示器 HDR 已设为\(l10n.vendorHDRTitle(mode))；切换时可能短暂黑屏。",
                          "Monitor HDR set to \(mode.title); the display may briefly blank.")) {
            try $0.setVendorHDR(mode)
        }
    }

    func setOverdrive(_ level: TitanArmyProfile.Overdrive) {
        perform(l10n.pick("响应速度已设为\(l10n.overdriveTitle(level))", "Overdrive set to \(level.title)")) {
            try $0.setOverdrive(level)
        }
    }

    func setLocalDimming(_ level: TitanArmyProfile.LocalDimming) {
        perform(l10n.pick("分区调光已设为\(l10n.localDimmingTitle(level))", "Local Dimming set to \(level.title)")) {
            try $0.setLocalDimming(level)
        }
    }

    func setSceneMode(_ mode: TitanArmyProfile.SceneMode) {
        perform(l10n.pick("场景模式已设为\(l10n.sceneModeTitle(mode))；请在显示器上确认画面。",
                          "Scene set to \(mode.title); confirm the picture on the monitor.")) {
            try $0.setSceneMode(mode)
        }
    }

    func setColorTemperature(_ temperature: TitanArmyProfile.ColorTemperature) {
        perform(l10n.pick("色温已设为\(l10n.colorTemperatureTitle(temperature))。",
                          "Color temperature set to \(temperature.title).")) {
            try $0.setColorTemperature(temperature)
        }
    }

    func setNightVision(_ level: TitanArmyProfile.NightVisionLevel) {
        perform(l10n.pick("夜视已设为\(l10n.nightVisionTitle(level))。", "Night vision set to \(level.title).")) {
            try $0.setNightVision(level)
        }
    }

    func setDynamicOverdrive(_ level: TitanArmyProfile.DynamicOverdriveLevel) {
        perform(l10n.pick("动态 OD 已设为\(l10n.dynamicOverdriveTitle(level))。", "Dynamic OD set to \(level.title).")) {
            try $0.setDynamicOverdrive(level)
        }
    }

    func setDyDsULL(_ level: TitanArmyProfile.DyDsULLLevel) {
        perform(l10n.pick("DyDs / ULL 已设为\(l10n.dyDsULLTitle(level))。", "DyDs / ULL set to \(level.title).")) {
            try $0.setDyDsULL(level)
        }
    }

    func setSharpness(_ level: TitanArmyProfile.SharpnessLevel) {
        perform(l10n.pick("锐度已设为\(l10n.sharpnessTitle(level))。", "Sharpness set to \(level.title).")) {
            try $0.setSharpness(level)
        }
    }

    func setLowBlueLight(_ level: TitanArmyProfile.LowBlueLightLevel) {
        perform(l10n.pick("低蓝光已设为\(l10n.lowBlueLightTitle(level))。", "Low blue light set to \(level.title).")) {
            try $0.setLowBlueLight(level)
        }
    }

    func setAdaptiveSync(_ enabled: Bool) {
        perform(l10n.pick("Adaptive-Sync 已\(enabled ? "开启" : "关闭")。",
                          "Adaptive-Sync turned \(enabled ? "on" : "off").")) {
            try $0.setAdaptiveSync(enabled)
        }
    }

    func setOfficialGamma(_ gamma: TitanArmyProfile.OfficialGamma) {
        perform(l10n.pick("官方 Gamma 已设为\(gamma.title)。", "Official gamma set to \(gamma.title).")) {
            try $0.setOfficialGamma(gamma)
        }
    }

    func setGameRush(_ enabled: Bool) {
        perform(l10n.pick("Game Rush 已\(enabled ? "开启" : "关闭")；相同状态已去重。",
                          "Game Rush turned \(enabled ? "on" : "off"); identical states are skipped.")) {
            try $0.setGameRush(enabled)
        }
    }

    func setEnhancement(_ enhancement: TitanArmyProfile.Enhancement, value: Int) {
        perform(l10n.pick("\(l10n.enhancementTitle(enhancement)) 已设为 \(value)。",
                          "\(enhancement.title) set to \(value).")) {
            try $0.setEnhancement(enhancement, value: value)
        }
    }

    func setRGBOutputRange(_ range: TitanArmyProfile.RGBOutputRange) {
        perform(l10n.pick("RGB 输出范围已设为\(l10n.rgbOutputRangeTitle(range))。",
                          "RGB output range set to \(range.title).")) {
            try $0.setRGBOutputRange(range)
        }
    }

    func setCustomScene(_ target: TitanArmyProfile.CustomSceneTarget, value: Int) {
        let title = l10n.windowsSettingTitle(target.windowsSetting)
        perform(l10n.pick("\(title)已设为 \(value)；请确认 Custom 场景已生效。",
                          "\(title) set to \(value); confirm the Custom scene is active.")) {
            try $0.setCustomScene(target, value: value)
        }
    }

    func setGameAssistant(_ command: TitanArmyProfile.GameAssistant.Command) {
        perform(l10n.pick("电竞助手设置已发送；请在显示器上确认覆盖层。",
                          "Game Assistant setting sent; confirm the overlay on the display.")) {
            try $0.setGameAssistant(command)
        }
    }

    func apply(_ preset: TitanArmyProfile.Preset) {
        perform(l10n.pick("已应用\(l10n.presetTitle(preset))预设", "Applied \(preset.title) preset")) {
            try $0.apply(preset)
        }
    }

    /// Runs a vendor write, then refreshes so the UI shows verified state.
    private func perform(_ successText: String, _ body: @escaping (MonitorController) throws -> Void) {
        guard let controller else { return }
        let language = self.language
        isBusy = true
        workQueue.async { [weak self] in
            var message: String? = successText
            var level = Notice.Level.info
            do {
                try body(controller)
            } catch {
                message = L10n(language: language).error(error)
                level = .error
            }
            let fresh = controller.snapshot(thorough: true)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.show(fresh)
                self.isBusy = false
                if let message {
                    self.notice = Notice(level: level, text: message)
                }
            }
        }
    }

    /// Publishes a fresh reading and moves the sliders to what the panel
    /// reports, unless the user is dragging one of them right now.
    private func show(_ fresh: DisplaySnapshot) {
        snapshot = fresh
        guard !isEditingTone else { return }
        if fresh.brightness.available { brightnessDraft = Double(fresh.brightness.value) }
        if fresh.contrast.available { contrastDraft = Double(fresh.contrast.value) }
        if fresh.volume.available { volumeDraft = Double(fresh.volume.value) }
    }

    func dismissNotice() {
        notice = nil
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
    }
}
