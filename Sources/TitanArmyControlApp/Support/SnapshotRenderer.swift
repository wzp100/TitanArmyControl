import AppKit
import ScreenCaptureKit
import SwiftUI

struct SnapshotConfiguration {
    let path: String
    let page: ContentView.Page
    let appearance: ColorScheme
    let language: AppLanguage?
    let size: CGSize
    let empty: Bool

    static func fromArguments() -> Self? {
        let args = CommandLine.arguments
        func option(_ name: String) -> String? {
            guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
            return args[index + 1]
        }
        guard let path = option("--render-snapshot") else { return nil }
        return Self(
            path: path,
            page: ContentView.Page(rawValue: option("--snapshot-page") ?? "display") ?? .display,
            appearance: option("--snapshot-appearance") == "dark" ? .dark : .light,
            language: option("--snapshot-language").flatMap(AppLanguage.init(rawValue:)),
            size: CGSize(width: Double(option("--snapshot-width") ?? "980") ?? 980,
                         height: Double(option("--snapshot-height") ?? "720") ?? 720),
            empty: args.contains("--snapshot-empty")
        )
    }
}

/// Capture only this process's real window. ScreenCaptureKit preserves native
/// Liquid Glass compositing, which NSView's bitmap cache does not render.
enum SnapshotRenderer {
    @MainActor
    static func capture(_ configuration: SnapshotConfiguration, model: MonitorViewModel) async {
        do {
            for _ in 0..<300 {
                if !model.isBusy { break }
                try await Task.sleep(for: .milliseconds(100))
            }
            guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else {
                throw CaptureError.noWindow
            }
            window.setContentSize(configuration.size)
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .seconds(1))

            // The SDK explicitly allows current-process windows without TCC consent.
            let content = try await SCShareableContent.currentProcess
            guard let target = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
                throw CaptureError.noWindow
            }
            let filter = SCContentFilter(desktopIndependentWindow: target)
            let settings = SCStreamConfiguration()
            let scale = window.backingScaleFactor
            settings.width = Int(window.frame.width * scale)
            settings.height = Int(window.frame.height * scale)
            settings.showsCursor = false
            settings.ignoreShadowsSingleWindow = true
            let captured = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: settings)
            let rep = NSBitmapImageRep(cgImage: captured)
            guard let data = rep.representation(using: .png, properties: [:]) else { throw CaptureError.encoding }
            try data.write(to: URL(fileURLWithPath: configuration.path))
            FileHandle.standardError.write(Data("render ok: \(configuration.path)\n".utf8))
            NSApp.terminate(nil)
        } catch {
            FileHandle.standardError.write(Data("render failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private enum CaptureError: Error { case noWindow, encoding }
}
