import SwiftUI
import TitanArmyCore

struct ContentView: View {
    enum Page: String, CaseIterable, Identifiable {
        case display, picture, information
        var id: String { rawValue }

        func title(_ l10n: L10n) -> String {
            switch self {
            case .display: return l10n.pick("显示与声音", "Display & Sound")
            case .picture: return l10n.pick("画面与响应", "Picture & Response")
            case .information: return l10n.pick("设备信息", "Device Information")
            }
        }

        var symbol: String {
            switch self {
            case .display: return "sun.max"
            case .picture: return "slider.horizontal.3"
            case .information: return "info.circle"
            }
        }
    }

    @EnvironmentObject private var model: MonitorViewModel
    @EnvironmentObject private var audio: SystemAudioModel
    @AppStorage("uiLanguage") private var storedLanguage = AppLanguage.systemDefault.rawValue
    @State private var page: Page?
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var showRegisters = false
    @State private var showExperimental = false
    @State private var showAudioUninstall = false
    @State private var enhancementDrafts: [TitanArmyProfile.Enhancement: Double] = [:]
    @State private var customSceneDrafts: [TitanArmyProfile.CustomSceneTarget: Double] = [:]

    private let languageOverride: AppLanguage?

    init(page: Page = .display, language: AppLanguage? = nil) {
        languageOverride = language
        _page = State(initialValue: page)
    }

    private var language: AppLanguage {
        languageOverride ?? AppLanguage(rawValue: storedLanguage) ?? .systemDefault
    }
    private var l10n: L10n { L10n(language: language) }
    private var currentPage: Page { page ?? .display }
    private var descriptor: DisplayDescriptor? {
        model.displays.first { $0.id == model.selectedDisplayID } ?? model.controller?.descriptor
    }
    private var hasControlReadings: Bool {
        model.snapshot.brightness.available || model.snapshot.contrast.available || model.snapshot.volume.available
    }
    private var canUseVendorControls: Bool {
        model.controller?.descriptor.isTargetModel == true && !model.isBusy
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            sidebar
                .navigationSplitViewColumnWidth(min: 208, ideal: 224, max: 280)
        } detail: {
            detail
                .navigationTitle(currentPage.title(l10n))
                .toolbar { toolbar }
        }
        .navigationSplitViewStyle(.balanced)
        .alert(l10n.pick("音频设置", "Audio Setup"), isPresented: Binding(
            get: { audio.failure != nil }, set: { if !$0 { audio.failure = nil } }
        )) {
            Button(l10n.pick("好", "OK"), role: .cancel) { audio.failure = nil }
        } message: { Text(audio.failure ?? "") }
        .confirmationDialog(l10n.pick("卸载系统音量组件？", "Uninstall the audio component?"),
                            isPresented: $showAudioUninstall, titleVisibility: .visible) {
            Button(l10n.pick("卸载", "Uninstall"), role: .destructive) { audio.uninstall() }
        } message: {
            Text(l10n.pick("将恢复之前的声音输出，移除音频组件。需要管理员认证。", "Restores your previous output and removes the audio component. Administrator authentication is required."))
        }
        .onAppear {
            model.setLanguage(language)
            audio.setDisplay(descriptor?.label, language: language)
            audio.handleLaunchRequest()
        }
        .onChange(of: descriptor?.id) { _, _ in audio.setDisplay(descriptor?.label, language: language) }
        .onChange(of: storedLanguage) { _, value in
            model.setLanguage(AppLanguage(rawValue: value) ?? .systemDefault)
            audio.setDisplay(descriptor?.label, language: language)
        }
    }

    private var sidebar: some View {
        List(selection: $page) {
            Section(l10n.pick("显示器", "Displays")) {
                if model.displays.isEmpty {
                    Label(l10n.pick("未连接显示器", "No display connected"), systemImage: "display")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, Layout.compact)
                }
                ForEach(model.displays) { display in
                    Button {
                        model.select(display)
                    } label: {
                        HStack(spacing: Layout.small) {
                            Image(systemName: display.isBuiltin ? "laptopcomputer" : "display")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: Layout.compact) {
                                Text(display.label)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                Text(display.isBuiltin
                                     ? l10n.pick("内建显示器", "Built-in display")
                                     : l10n.pick("外接显示器", "External display"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if display.id == model.selectedDisplayID {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        .padding(.vertical, Layout.compact)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isBusy)
                    .accessibilityLabel(display.label)
                    .accessibilityAddTraits(display.id == model.selectedDisplayID ? .isSelected : [])
                    .help(display.label)
                    .contextMenu {
                        Button(l10n.pick("拷贝显示器名称", "Copy Display Name"), systemImage: "doc.on.doc") {
                            copy(display.label)
                        }
                        Button(l10n.pick("刷新显示器", "Refresh Displays"), systemImage: "arrow.clockwise") {
                            model.refresh(thorough: true)
                        }
                        .disabled(model.isBusy)
                    }
                }
            }
            Section(l10n.pick("控制", "Controls")) {
                ForEach(Page.allCases) { item in
                    Label(item.title(l10n), systemImage: item.symbol)
                        .tag(item)
                        .padding(.vertical, Layout.compact)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("TitanArmyControl")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: Layout.small) {
                if model.isBusy {
                    ProgressView().controlSize(.mini)
                    Text(l10n.pick("正在同步显示器…", "Syncing display…"))
                } else {
                    Image(systemName: model.controller != nil ? "cable.connector" : "cable.connector.slash")
                    Text(model.controller != nil
                         ? (hasControlReadings ? l10n.pick("DDC/CI 已连接", "DDC/CI connected") : l10n.pick("DDC/CI 未响应", "DDC/CI not responding"))
                         : l10n.pick("等待连接", "Waiting for connection"))
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(Layout.regular)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker(l10n.pick("界面语言", "Language"), selection: $storedLanguage) {
                    Text("简体中文").tag(AppLanguage.chinese.rawValue)
                    Text("English").tag(AppLanguage.english.rawValue)
                }
            } label: {
                Label(l10n.pick("界面语言", "Language"), systemImage: "globe")
            }
            .help(l10n.pick("界面语言", "Language"))

            Button {
                model.refresh(thorough: true)
            } label: {
                Label(l10n.pick("刷新", "Refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(model.isBusy)
            .help(l10n.pick("重新读取显示器（⌘R）", "Refresh display (⌘R)"))
        }
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.large) {
                if let notice = model.notice {
                    NoticeBar(notice: notice, dismissTitle: l10n.pick("关闭提示", "Dismiss")) {
                        model.dismissNotice()
                    }
                }

                if model.isBusy && descriptor == nil {
                    loadingState
                } else if descriptor == nil {
                    emptyState
                } else {
                    switch currentPage {
                    case .display: displayPage
                    case .picture: picturePage
                    case .information: informationPage
                    }
                }
            }
            .frame(maxWidth: Layout.contentWidth, alignment: .leading)
            .padding(Layout.page)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Palette.background)
    }

    private var displayPage: some View {
        VStack(alignment: .leading, spacing: Layout.large) {
            displaySummary
            SettingsGroup(
                title: l10n.pick("显示", "Display"),
                footer: model.snapshot.brightnessLockedByHDR
                    ? l10n.pick("HDR 已开启，显示器会锁定亮度和对比度。关闭 HDR 后即可调整。",
                                "HDR locks brightness and contrast. Turn it off to adjust them.")
                    : nil
            ) {
                ToneControl(
                    title: l10n.pick("亮度", "Brightness"), symbol: "sun.max",
                    maximum: max(model.snapshot.brightness.maximum, 100),
                    value: $model.brightnessDraft,
                    disabled: model.isBusy || model.snapshot.brightnessLockedByHDR,
                    available: model.snapshot.brightness.available,
                    onChange: model.previewBrightness, onCommit: model.commitBrightness
                )
                SettingsDivider()
                ToneControl(
                    title: l10n.pick("对比度", "Contrast"), symbol: "circle.lefthalf.filled",
                    maximum: max(model.snapshot.contrast.maximum, 100),
                    value: $model.contrastDraft,
                    disabled: model.isBusy || model.snapshot.brightnessLockedByHDR,
                    available: model.snapshot.contrast.available,
                    onChange: model.previewContrast, onCommit: model.commitContrast
                )
                SettingsDivider()
                HStack(spacing: Layout.medium) {
                    SettingIcon(symbol: "sparkles.tv")
                    VStack(alignment: .leading, spacing: Layout.compact) {
                        Text(l10n.pick("高动态范围", "High Dynamic Range"))
                        Text(l10n.pick("HDR · 呈现更丰富的亮部与色彩", "HDR · Richer highlights and color"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Layout.small)
                    Toggle(l10n.pick("高动态范围", "High Dynamic Range"), isOn: Binding(
                        get: { model.isHDREnabled },
                        set: { model.setSystemHDR($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(model.isBusy || model.snapshot.hdrEnabled == nil)
                    .help(l10n.pick("切换 HDR 时显示器可能短暂黑屏，通常需要 6–12 秒。",
                                    "The display may go black for 6–12 seconds while HDR changes."))
                }
                .padding(Layout.regular)
            }
            soundSettings
            if !model.snapshot.brightness.available || !model.snapshot.contrast.available || !model.snapshot.volume.available {
                Label(l10n.pick("部分设置暂时无法读取，请刷新重试。", "Some settings are unavailable. Refresh to try again."),
                      systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var soundSettings: some View {
        SettingsGroup(title: l10n.pick("声音", "Sound"), footer: audio.usesSystemVolume
                      ? (audio.isDefaultOutput
                         ? l10n.pick("系统音量与音量键同步；显示器音量直接调节显示器扬声器。", "System volume follows the volume keys. Monitor sets the display’s own speaker level.")
                         : l10n.pick("此音量用于显示器，选择“使用显示器”后生效。", "This volume applies to the display. Choose Use Display to hear it."))
                      : l10n.pick("启用系统音量后，即可使用音量键、静音键和控制中心。", "Enable system volume to use volume keys, mute and Control Center.")) {
            HStack(spacing: Layout.medium) {
                SettingIcon(symbol: "hifispeaker")
                VStack(alignment: .leading, spacing: Layout.compact) {
                    Text(l10n.pick("系统音量", "System Volume"))
                    Text(audio.isDefaultOutput
                         ? l10n.pick("正在通过显示器播放", "Playing through your display")
                         : l10n.pick("当前输出：", "Current output: ") + (audio.currentOutput?.name ?? "—"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(audio.currentOutput?.name ?? "")
                }
                Spacer(minLength: Layout.small)
                if audio.isWorking {
                    ProgressView().controlSize(.small)
                } else if !audio.isInstalled {
                    Button(l10n.pick("启用…", "Enable…")) { audio.install() }
                        .buttonStyle(.glass)
                        .disabled(audio.selectedEndpoint == nil)
                        .help(l10n.pick("安装系统音量组件并将声音输出切换到显示器。需要管理员认证。", "Installs the audio component and selects the display as sound output. Requires administrator authentication."))
                } else if !audio.isDefaultOutput {
                    Button(audio.proxy == nil ? l10n.pick("重新加载…", "Reload…") : l10n.pick("使用显示器", "Use Display")) {
                        if audio.proxy == nil { audio.install() } else { audio.activate() }
                    }
                    .buttonStyle(.glass)
                    .disabled(audio.selectedEndpoint == nil)
                }
                if audio.isInstalled {
                    Menu {
                        Button(l10n.pick("恢复之前的输出", "Restore Previous Output")) { audio.disable() }
                            .disabled(!audio.isDefaultOutput)
                        Divider()
                        Button(l10n.pick("卸载音频组件…", "Uninstall Audio Component…"), role: .destructive) { showAudioUninstall = true }
                    } label: {
                        Label(l10n.pick("音频选项", "Audio Options"), systemImage: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .labelsHidden()
                    .fixedSize()
                    .disabled(audio.isWorking)
                    .help(l10n.pick("音频选项", "Audio Options"))
                }
            }
            .padding(Layout.regular)
            SettingsDivider()
            if audio.usesSystemVolume {
                ToneControl(title: l10n.pick("系统", "System"), symbol: "speaker.wave.2", maximum: 100,
                            value: $audio.volumeDraft, disabled: audio.isWorking, available: true,
                            onChange: audio.previewVolume, onCommit: audio.commitVolume,
                            isMuted: audio.isMuted,
                            muteLabel: audio.isMuted ? l10n.pick("取消静音", "Unmute") : l10n.pick("静音", "Mute"),
                            onMute: audio.toggleMute)
                SettingsDivider()
            }
            // The panel's own speaker level (DDC 0x62), independent of the
            // system software volume above.
            ToneControl(title: l10n.pick("显示器", "Monitor"), symbol: "hifispeaker",
                        maximum: max(model.snapshot.volume.maximum, 100), value: $model.volumeDraft,
                        disabled: model.isBusy, available: model.snapshot.volume.available,
                        onChange: model.previewVolume, onCommit: model.commitVolume)
        }
    }

    private var displaySummary: some View {
        HStack(spacing: Layout.large) {
            DisplayIllustration()
            VStack(alignment: .leading, spacing: Layout.medium) {
                VStack(alignment: .leading, spacing: Layout.compact) {
                    Text(descriptor?.isTargetModel == true ? "TITAN ARMY" : (descriptor?.manufacturer ?? ""))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(descriptor?.label ?? "—")
                        .font(.title3.weight(.semibold))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let descriptor {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Layout.medium) {
                            Text(verbatim: "\(descriptor.widthPixels) × \(descriptor.heightPixels)")
                            Text("·").foregroundStyle(.tertiary)
                            Text(String(format: "%.0f Hz", descriptor.refreshRate))
                        }
                        VStack(alignment: .leading, spacing: Layout.compact) {
                            Text(verbatim: "\(descriptor.widthPixels) × \(descriptor.heightPixels)")
                            Text(String(format: "%.0f Hz", descriptor.refreshRate))
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                StatusLabel(title: l10n.pick("已连接", "Connected"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Layout.small)
        .accessibilityElement(children: .combine)
    }

    private var picturePage: some View {
        VStack(alignment: .leading, spacing: Layout.large) {
            pageHeading(l10n.pick("适合当下的画面", "A picture for every task"),
                        subtitle: l10n.pick("使用官方场景协议选择 15 种场景和 Custom，并单独调整响应、色温与其他画面功能。", "Use the official scene protocol for 15 scenes plus Custom and tune response, color and other picture features."))
            if descriptor?.isTargetModel != true {
                Label(l10n.pick("此型号仅支持标准显示与声音设置。", "This model supports standard display and sound settings only."),
                      systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
            SettingsGroup(
                title: l10n.pick("官方场景模式", "Official Scene Modes"),
                footer: l10n.pick("来自官方 Windows 工具的二段式协议。选择后会改变画面；macOS 通道不能回读私有状态，以下选择不代表检测到的当前状态。", "Two-write protocol from the official Windows utility. Selection changes the picture. The macOS channel cannot read these private states, so the selection is the requested value, not a detected state.")
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 300), spacing: Layout.medium)],
                          alignment: .leading, spacing: Layout.medium) {
                    ForEach(TitanArmyProfile.SceneMode.allCases, id: \.self) { mode in
                        Button {
                            model.setSceneMode(mode)
                        } label: {
                            VStack(alignment: .leading, spacing: Layout.compact) {
                                Text(l10n.sceneModeTitle(mode))
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                Text(l10n.sceneModeDetail(mode))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
                        }
                        .buttonStyle(.glass)
                        .disabled(!canUseVendorControls)
                        .accessibilityLabel(l10n.pick("应用\(l10n.sceneModeTitle(mode))场景", "Apply \(mode.title) scene"))
                        .help(String(format: "0x99 ← 0x%02X · 0x22 ← 0x%02X", mode.rawValue, mode.rawValue))
                    }
                }
                .padding(Layout.regular)
            }
            SettingsGroup(
                title: l10n.pick("官方游戏与 Gamma", "Official Game & Gamma"),
                footer: l10n.pick("官方工具的开关状态由应用记录；重复点击同一状态不会重复写入显示器。", "The app mirrors official toggle state; repeated identical clicks do not write to the display again.")
            ) {
                vendorMenuRow(icon: "circle.hexagongrid.circle", title: l10n.pick("官方 Gamma", "Official Gamma"), setting: .gamma) {
                    ForEach(TitanArmyProfile.OfficialGamma.allCases, id: \.self) { mode in
                        Button(l10n.officialGammaTitle(mode)) { model.setOfficialGamma(mode) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "flag.checkered", title: "Game Rush", setting: .gameRush) {
                    Button(l10n.pick("关闭", "Off")) { model.setGameRush(false) }
                    Button(l10n.pick("开启", "On")) { model.setGameRush(true) }
                }
                SettingsDivider()
                vendorMenuRow(icon: "target", title: l10n.pick("电竞助手 · 屏幕与位置", "Game Assistant · Screen & Position"), setting: .gameAssistantScreenSize) {
                    ForEach(TitanArmyProfile.GameAssistant.ScreenSize.allCases, id: \.self) { size in
                        Button(size.title) { model.setGameAssistant(.screenSize(size)) }
                    }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.RefreshPosition.allCases, id: \.self) { position in
                        Button(l10n.pick("刷新率 · \(position.title)", "Refresh Rate · \(position.title)")) {
                            model.setGameAssistant(.refreshPosition(position))
                        }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "cross.fill", title: l10n.pick("电竞助手 · 准星", "Game Assistant · Crosshair"), setting: .gameAssistantCrosshair) {
                    Button(l10n.pick("关闭", "Off")) { model.setGameAssistant(.crosshair(.off)) }
                    Button(l10n.pick("开启", "On")) { model.setGameAssistant(.crosshair(.on)) }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.CrosshairShape.allCases, id: \.self) { shape in
                        Button(shape.title) { model.setGameAssistant(.crosshairShape(shape)) }
                    }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.CrosshairColor.allCases, id: \.self) { color in
                        Button(color.title) { model.setGameAssistant(.crosshairColor(color)) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "timer", title: l10n.pick("电竞助手 · 秒表", "Game Assistant · Stopwatch"), setting: .gameAssistantStopwatch) {
                    Button(l10n.pick("关闭", "Off")) { model.setGameAssistant(.stopwatch(.off)) }
                    Button(l10n.pick("开启", "On")) { model.setGameAssistant(.stopwatch(.on)) }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.Duration.allCases, id: \.self) { duration in
                        Button(duration.title) { model.setGameAssistant(.stopwatchTime(duration)) }
                    }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.Position.allCases, id: \.self) { position in
                        Button(position.title) { model.setGameAssistant(.stopwatchPosition(position)) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "clock.badge.checkmark", title: l10n.pick("电竞助手 · 游戏时间", "Game Assistant · Game Time"), setting: .gameAssistantGameTime) {
                    Button(l10n.pick("关闭", "Off")) { model.setGameAssistant(.gameTime(.off)) }
                    Button(l10n.pick("开启", "On")) { model.setGameAssistant(.gameTime(.on)) }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.Duration.allCases, id: \.self) { duration in
                        Button(duration.title) { model.setGameAssistant(.gameTimeValue(duration)) }
                    }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.Position.allCases, id: \.self) { position in
                        Button(position.title) { model.setGameAssistant(.gameTimePosition(position)) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "plus.magnifyingglass", title: l10n.pick("电竞助手 · 放大镜", "Game Assistant · Magnifier"), setting: .gameAssistantMagnifier) {
                    Button(l10n.pick("关闭", "Off")) { model.setGameAssistant(.magnifier(.off)) }
                    Button(l10n.pick("开启", "On")) { model.setGameAssistant(.magnifier(.on)) }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.MagnifierSize.allCases, id: \.self) { size in
                        Button(size.title) { model.setGameAssistant(.magnifierSize(size)) }
                    }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.Magnification.allCases, id: \.self) { magnification in
                        Button(magnification.title) { model.setGameAssistant(.magnification(magnification)) }
                    }
                    Divider()
                    ForEach(TitanArmyProfile.GameAssistant.MagnifierPosition.allCases, id: \.self) { position in
                        Button(position.title) { model.setGameAssistant(.magnifierPosition(position)) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "scope", title: l10n.pick("电竞助手 · 瞄准线与鹰眼", "Game Assistant · Alignment & HawkEye"), setting: .gameAssistantAlignment) {
                    Button(l10n.pick("瞄准线关闭", "Alignment off")) { model.setGameAssistant(.alignment(.off)) }
                    Button(l10n.pick("瞄准线开启", "Alignment on")) { model.setGameAssistant(.alignment(.on)) }
                    Divider()
                    Button(l10n.pick("鹰眼关闭", "HawkEye off")) { model.setGameAssistant(.hawkEye(.off)) }
                    Button(l10n.pick("鹰眼开启", "HawkEye on")) { model.setGameAssistant(.hawkEye(.on)) }
                }
            }
            SettingsGroup(
                title: l10n.pick("响应速度", "Response Time"),
                footer: l10n.pick("更高的响应加速可减少拖影，也可能产生过冲。", "Higher overdrive can reduce motion blur, but may introduce overshoot.")
            ) {
                HStack(spacing: Layout.medium) {
                    SettingIcon(symbol: "speedometer")
                    Text("Overdrive")
                    Spacer(minLength: Layout.small)
                    Picker("Overdrive", selection: Binding(
                        get: { model.snapshot.overdrive.available ? Int(model.snapshot.overdrive.value) : -1 },
                        set: { value in
                            if value >= 0, let level = TitanArmyProfile.Overdrive(rawValue: UInt16(value)) { model.setOverdrive(level) }
                        }
                    )) {
                        if !model.snapshot.overdrive.available {
                            Text(l10n.pick("不可用", "Unavailable")).tag(-1)
                        } else if model.snapshot.overdrive.value > 3 {
                            Text(l10n.pick("等级 \(model.snapshot.overdrive.value)", "Level \(model.snapshot.overdrive.value)"))
                                .tag(model.snapshot.overdrive.value)
                        }
                        ForEach(TitanArmyProfile.Overdrive.allCases, id: \.self) { level in
                            Text(l10n.overdriveTitle(level)).tag(Int(level.rawValue))
                        }
                    }
                    .labelsHidden()
                    .frame(width: Layout.controlWidth)
                    .disabled(!canUseVendorControls || !model.snapshot.overdrive.available)
                }
                .padding(Layout.regular)
            }
            SettingsGroup(
                title: l10n.pick("分区调光", "Local Dimming"),
                footer: l10n.protocolEvidence(.localDimming)
            ) {
                HStack(spacing: Layout.medium) {
                    SettingIcon(symbol: "rectangle.split.2x2")
                    Text(l10n.pick("局部调光", "Local Dimming"))
                    Spacer(minLength: Layout.small)
                    Menu {
                        ForEach(TitanArmyProfile.LocalDimming.allCases, id: \.self) { level in
                            Button(l10n.localDimmingTitle(level)) { model.setLocalDimming(level) }
                        }
                    } label: {
                        Label(l10n.pick("选择模式", "Choose Mode"), systemImage: "slider.horizontal.2")
                    }
                    .frame(width: Layout.controlWidth)
                    .disabled(!canUseVendorControls)
                    .help(l10n.pick("设置分区调光级别", "Set local dimming level"))
                }
                .padding(Layout.regular)
            }
            SettingsGroup(
                title: l10n.pick("画面增强与护眼", "Picture Enhancement & Comfort"),
                footer: l10n.pick("这些是官方程序映射中的私有寄存器。当前实机探测确认它们不可回读，界面不会伪造当前状态。", "These are private registers mapped from the official program. Hardware probing confirms they are not readable here, so the UI does not fabricate current state.")
            ) {
                vendorMenuRow(icon: "thermometer.medium", title: l10n.pick("色温", "Color Temperature"), setting: .colorTemperature) {
                    ForEach(TitanArmyProfile.ColorTemperature.allCases, id: \.self) { mode in
                        Button(l10n.colorTemperatureTitle(mode)) { model.setColorTemperature(mode) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "moon.stars", title: l10n.pick("夜视", "Night Vision"), setting: .nightVision) {
                    ForEach(TitanArmyProfile.NightVisionLevel.allCases, id: \.self) { level in
                        Button(l10n.nightVisionTitle(level)) { model.setNightVision(level) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "hare", title: l10n.pick("动态 OD", "Dynamic OD"), setting: .dynamicOverdrive) {
                    ForEach(TitanArmyProfile.DynamicOverdriveLevel.allCases, id: \.self) { level in
                        Button(l10n.dynamicOverdriveTitle(level)) { model.setDynamicOverdrive(level) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "bolt.badge.clock", title: l10n.pick("DyDs / ULL", "DyDs / ULL"), setting: .dyDsULL) {
                    ForEach(TitanArmyProfile.DyDsULLLevel.allCases, id: \.self) { level in
                        Button(l10n.dyDsULLTitle(level)) { model.setDyDsULL(level) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "triangle", title: l10n.pick("锐度", "Sharpness"), setting: .sharpness) {
                    ForEach(TitanArmyProfile.SharpnessLevel.allCases, id: \.self) { level in
                        Button(l10n.sharpnessTitle(level)) { model.setSharpness(level) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "lightbulb.min", title: l10n.pick("低蓝光", "Low Blue Light"), setting: .lowBlueLight) {
                    ForEach(TitanArmyProfile.LowBlueLightLevel.allCases, id: \.self) { level in
                        Button(l10n.lowBlueLightTitle(level)) { model.setLowBlueLight(level) }
                    }
                }
                SettingsDivider()
                vendorMenuRow(icon: "wand.and.stars", title: l10n.pick("输出范围", "Output Range"), setting: .rgbOutputRange) {
                    ForEach(TitanArmyProfile.RGBOutputRange.allCases, id: \.self) { range in
                        Button(l10n.rgbOutputRangeTitle(range)) { model.setRGBOutputRange(range) }
                    }
                }
                SettingsDivider()
                // A menu, not a picker: the state is not readable, so a picker
                // bound to a placeholder value could never send that value.
                vendorMenuRow(icon: "arrow.triangle.swap", title: "Adaptive-Sync", setting: .adaptiveSync) {
                    Button(l10n.pick("关闭", "Off")) { model.setAdaptiveSync(false) }
                    Button(l10n.pick("开启", "On")) { model.setAdaptiveSync(true) }
                }
            }
            SettingsGroup(
                title: l10n.pick("Custom 场景调校", "Custom Scene Tuning"),
                footer: l10n.pick("官方 Custom 页的图像子项。必须先选择 Custom 场景；目标寄存器来自官方调用点，画面效果需显示器确认。", "Custom-page image controls. Select the Custom scene first. Targets come from official call sites; confirm the result on the display.")
            ) {
                ForEach(TitanArmyProfile.CustomSceneTarget.allCases, id: \.self) { target in
                    if target != .saturation {
                        SettingsDivider()
                    }
                    HStack(spacing: Layout.medium) {
                        SettingIcon(symbol: customSceneSymbol(target))
                        VStack(alignment: .leading, spacing: Layout.compact) {
                            Text(l10n.windowsSettingTitle(target.windowsSetting))
                            Text(String(format: "%d / %d", customSceneValue(target), target.allowedRange.upperBound))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(customSceneValue(target)) },
                                set: { customSceneDrafts[target] = $0 }
                            ),
                            in: Double(target.allowedRange.lowerBound)...Double(target.allowedRange.upperBound),
                            step: 1
                        ) { editing in
                            // Write once when the drag ends, never on touch-down.
                            if !editing { model.setCustomScene(target, value: customSceneValue(target)) }
                        }
                        .frame(width: Layout.sliderWidth)
                        .disabled(!canUseVendorControls)
                        .accessibilityLabel(l10n.windowsSettingTitle(target.windowsSetting))
                    }
                    .padding(Layout.regular)
                }
            }
            SettingsGroup(
                title: l10n.pick("官方画面增强滑条", "Official Enhancement Sliders"),
                footer: l10n.pick("拖动结束才写入。范围和目标寄存器来自官方工具；私有状态不可回读。", "Writes happen when the drag ends. Ranges and targets come from the official utility; private state is not readable.")
            ) {
                ForEach(TitanArmyProfile.Enhancement.allCases, id: \.self) { enhancement in
                    if enhancement != .colorEnhance {
                        SettingsDivider()
                    }
                    HStack(spacing: Layout.medium) {
                        SettingIcon(symbol: enhancementSymbol(enhancement))
                        VStack(alignment: .leading, spacing: Layout.compact) {
                            Text(l10n.enhancementTitle(enhancement))
                            Text(String(format: "%d / %d", enhancementValue(enhancement), enhancement.allowedRange.upperBound))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(enhancementValue(enhancement)) },
                                set: { enhancementDrafts[enhancement] = $0 }
                            ),
                            in: Double(enhancement.allowedRange.lowerBound)...Double(enhancement.allowedRange.upperBound),
                            step: 1
                        ) { editing in
                            if !editing { model.setEnhancement(enhancement, value: enhancementValue(enhancement)) }
                        }
                        .frame(width: Layout.sliderWidth)
                        .disabled(!canUseVendorControls)
                        .accessibilityLabel(l10n.enhancementTitle(enhancement))
                    }
                    .padding(Layout.regular)
                }
            }
            DisclosureGroup(isExpanded: $showExperimental) {
                VStack(alignment: .leading, spacing: Layout.medium) {
                    Text(l10n.pick("显示器 HDR 模式来自参考协议，完整含义尚未确认。通常只需在“显示与声音”中切换 macOS HDR。",
                                    "Monitor HDR modes come from a reference protocol and are not fully confirmed. For everyday use, change macOS HDR in Display & Sound."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Menu {
                        Button(l10n.pick("关闭", "Off")) { model.setVendorHDR(.off) }
                        Button(l10n.pick("游戏 HDR", "Game HDR")) { model.setVendorHDR(.game) }
                    } label: {
                        Label(l10n.pick("显示器 HDR", "Monitor HDR"), systemImage: "sparkles.tv")
                    }
                    .frame(width: Layout.controlWidth)
                    .disabled(!canUseVendorControls)
                }
                .padding(.top, Layout.medium)
            } label: {
                Label(l10n.pick("实验性设置", "Experimental Settings"), systemImage: "flask")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Layout.compact)
        }
    }

    private func vendorMenuRow<Content: View>(icon: String,
                                              title: String,
                                              setting: TitanArmyProfile.WindowsSetting,
                                              @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: Layout.medium) {
            SettingIcon(symbol: icon)
            VStack(alignment: .leading, spacing: Layout.compact) {
                Text(title)
                Text(l10n.protocolEvidence(setting))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Layout.small)
            Menu {
                content()
            } label: {
                Label(l10n.pick("选择等级", "Choose Level"), systemImage: "slider.horizontal.2")
            }
            .frame(width: Layout.controlWidth)
            .disabled(!canUseVendorControls)
        }
        .padding(Layout.regular)
        .accessibilityElement(children: .combine)
    }

    private func enhancementValue(_ enhancement: TitanArmyProfile.Enhancement) -> Int {
        enhancementDrafts[enhancement].map { Int($0.rounded()) } ?? enhancement.allowedRange.lowerBound
    }

    private func customSceneValue(_ target: TitanArmyProfile.CustomSceneTarget) -> Int {
        let range = target.allowedRange
        let draft = customSceneDrafts[target].map { Int($0.rounded()) } ?? (range.lowerBound + range.upperBound) / 2
        return min(max(draft, range.lowerBound), range.upperBound)
    }

    private func enhancementSymbol(_ enhancement: TitanArmyProfile.Enhancement) -> String {
        switch enhancement {
        case .colorEnhance: return "paintpalette"
        case .crEnhance: return "circle.grid.cross"
        case .shadowBalance: return "moon.haze"
        case .superResolution: return "arrow.up.left.and.arrow.down.right"
        case .haloControl: return "lightbulb.max"
        }
    }

    private func customSceneSymbol(_ target: TitanArmyProfile.CustomSceneTarget) -> String {
        switch target {
        case .saturation: return "paintpalette"
        case .gamma: return "circle.hexagongrid.circle"
        case .hue: return "rainbow"
        case .nightVision: return "moon.stars"
        case .dynamicOverdrive: return "hare"
        case .crEnhance: return "circle.grid.cross"
        case .colorEnhance: return "wand.and.stars"
        }
    }

    private var informationPage: some View {
        VStack(alignment: .leading, spacing: Layout.large) {
            pageHeading(l10n.pick("了解你的显示器", "About your display"),
                        subtitle: l10n.pick("连接信息、硬件能力与本机验证记录。", "Connection details, capabilities and hardware findings."))
            SettingsGroup(title: l10n.pick("设备", "Device")) {
                if let descriptor {
                    informationRow(l10n.pick("型号", "Model"), descriptor.label)
                    SettingsDivider()
                    informationRow(l10n.pick("分辨率", "Resolution"), "\(descriptor.widthPixels) × \(descriptor.heightPixels)")
                    SettingsDivider()
                    informationRow(l10n.pick("刷新率", "Refresh Rate"), String(format: "%.0f Hz", descriptor.refreshRate))
                    SettingsDivider()
                    informationRow("EDID", "\(descriptor.manufacturer) · 0x\(String(format: "%04X", descriptor.modelNumber))")
                    SettingsDivider()
                    informationRow(l10n.pick("上次读取", "Last Read"), model.snapshot.timestamp.formatted(date: .omitted, time: .standard))
                }
                SettingsDivider()
                DisclosureGroup(l10n.pick("DDC/CI 连接路径", "DDC/CI Connection Path")) {
                    Text(model.controller?.session.endpoint.servicePath ?? "—")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Layout.small)
                }
                .padding(Layout.regular)
            }
            VStack(alignment: .leading, spacing: Layout.regular) {
                Text(l10n.pick("本机实测", "Hardware Findings")).font(.headline)
                ForEach(HardwareFindings.all) { finding in
                    HStack(alignment: .top, spacing: Layout.medium) {
                        Image(systemName: finding.status == .confirmed ? "checkmark.circle" : "info.circle")
                            .foregroundStyle(finding.status == .confirmed ? Color.green : Color.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: Layout.compact) {
                            Text(l10n.findingTitle(finding))
                            Text(l10n.findingDetail(finding))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.compact)
            Divider()
            DisclosureGroup(l10n.pick("寄存器参考", "Register Reference"), isExpanded: $showRegisters) {
                Grid(alignment: .leading, horizontalSpacing: Layout.regular, verticalSpacing: Layout.medium) {
                    ForEach(TitanArmyProfile.registers, id: \.vcp) { register in
                        GridRow {
                            Text(String(format: "0x%02X", register.vcp)).font(.caption.monospaced())
                            Text(l10n.registerTitle(register.vcp)).frame(maxWidth: .infinity, alignment: .leading)
                            Text(l10n.certainty(register.certainty)).foregroundStyle(.secondary)
                        }
                        .help(l10n.registerNote(register.vcp))
                    }
                }
                .font(.callout)
                .padding(.top, Layout.regular)
            }
            .padding(.horizontal, Layout.compact)
        }
    }

    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Layout.small) {
            Text(title).font(.title3.weight(.semibold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .padding(.bottom, Layout.small)
    }

    private func informationRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.regular) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: Layout.small)
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .padding(.horizontal, Layout.regular)
        .padding(.vertical, Layout.medium)
    }

    private var loadingState: some View {
        VStack(spacing: Layout.regular) {
            ProgressView()
            Text(l10n.pick("正在连接显示器", "Connecting to your display")).font(.headline)
            Text(l10n.pick("正在读取显示设置，请稍候。", "Reading your display settings. This may take a moment."))
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(model.displays.isEmpty
                  ? l10n.pick("连接你的显示器", "Connect your display")
                  : l10n.pick("无法控制此显示器", "Display controls unavailable"), systemImage: "display")
        } description: {
            Text(l10n.pick("使用 DisplayPort 或 USB-C 连接外接显示器，并在显示器菜单中开启 DDC/CI。",
                           "Connect an external display using DisplayPort or USB-C and enable DDC/CI in its on-screen menu."))
        } actions: {
            Button(l10n.pick("重新检测", "Detect Displays")) { model.refresh(thorough: true) }
                .buttonStyle(.glass)
                .disabled(model.isBusy)
        }
        .frame(maxWidth: .infinity, minHeight: 380)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
