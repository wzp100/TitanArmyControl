import SwiftUI
import TitanArmyCore

@main
struct TitanArmyApp: App {
    @StateObject private var model: MonitorViewModel
    @StateObject private var audio = SystemAudioModel()
    @AppStorage("uiLanguage") private var storedLanguage = AppLanguage.systemDefault.rawValue
    private let snapshot: SnapshotConfiguration?

    init() {
        let configuration = SnapshotConfiguration.fromArguments()
        if configuration != nil,
           let session = CGSessionCopyCurrentDictionary() as? [String: Any],
           session["CGSSessionScreenIsLocked"] as? Bool == true {
            FileHandle.standardError.write(Data("render unavailable: unlock the Mac before capturing its native window.\n".utf8))
            exit(1)
        }
        snapshot = configuration
        _model = StateObject(wrappedValue: MonitorViewModel(autostart: configuration?.empty != true))
    }

    var body: some Scene {
        WindowGroup("Titan Army") {
            ContentView(page: snapshot?.page ?? .display, language: snapshot?.language)
                .environmentObject(model)
                .environmentObject(audio)
                .frame(minWidth: 760, minHeight: 620)
                .preferredColorScheme(snapshot?.appearance)
                .task {
                    if let snapshot { await SnapshotRenderer.capture(snapshot, model: model) }
                }
        }
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(snapshot == nil ? .automatic : .disabled)
        .defaultSize(width: 980, height: 720)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(l10n.pick("显示器", "Monitor")) {
                Button(l10n.pick("刷新", "Refresh")) { model.refresh(thorough: true) }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.isBusy)
                Divider()
                ForEach(TitanArmyProfile.presets) { preset in
                    Button(l10n.pick("应用\(l10n.presetTitle(preset))预设",
                                     "Apply \(l10n.presetTitle(preset)) Preset")) {
                        model.apply(preset)
                    }
                    .disabled(model.isBusy || model.controller?.descriptor.isTargetModel != true)
                }
            }
        }
    }

    private var l10n: L10n {
        L10n(language: AppLanguage(rawValue: storedLanguage) ?? .systemDefault)
    }
}
