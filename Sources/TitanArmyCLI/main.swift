import Foundation
import CoreAudio
import TitanArmyCore

// A small, scriptable front end used both by people and by the test harness.

let arguments = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    titanarmyctl - macOS CLI for TitanArmyControl and the Titan Army P275MV PLUS

    USAGE
      titanarmyctl audio status            Inspect audio routing and native volume
      titanarmyctl audio enable            Select system volume for the display
      titanarmyctl audio disable           Restore previous sound outputs
      titanarmyctl audio volume <0-100>     Set system software volume
      titanarmyctl audio mute <on|off>      Set system mute
      titanarmyctl list                      List online displays
      titanarmyctl status [--display N]      Read current monitor state
      titanarmyctl probe [--display N]       Enumerate every readable VCP
      titanarmyctl set <vcp> <value>         Write one profiled VCP and verify it stuck
      titanarmyctl brightness <0-100>        Set hardware brightness
      titanarmyctl contrast <0-100>          Set contrast
      titanarmyctl volume <0-100>            Set monitor speaker volume
      titanarmyctl scene <standard|rtsrpg|fps|moba|movie|reading|night|eyecare|macview|ebook|srgb|adobe|dcip3|dydsfps|dydsld|custom>
      titanarmyctl colortemp <warm|natural|cold|user1|user2|user3>
      titanarmyctl nightvision <0-4>
      titanarmyctl dynamicod <0-4>
      titanarmyctl dydsull <off|3|4|5|6|7|8>
      titanarmyctl sharpness <0-4>
      titanarmyctl lowbluelight <0-4>
      titanarmyctl adaptivesync <on|off>
      titanarmyctl gammavendor <2|4|6|8|10|12>
      titanarmyctl gamerush <on|off>
      titanarmyctl enhance <color|cr|shadow|sr|halo> <value>
      titanarmyctl custom <saturation|gamma|hue|nightvision|od|cr|color> <value>
      titanarmyctl outputrange <auto|limited|full>
      titanarmyctl hdr <on|off|status>       Read or toggle macOS HDR
      titanarmyctl od <off|normal|fast|fastest>
      titanarmyctl vendorhdr <off|auto|game|movie>
      titanarmyctl localdimming <off|low|smooth|medium|high>
      titanarmyctl monitorhdr <off|game|movie>
      titanarmyctl assistant <command> [value]
        Commands: screen <full|wide|25|27|32>, refreshpos <0-3>
                  crosshair <on|off|1-6>, crosshaircolor <red|yellow|green|cyan|blue|purple|white|auto>
                  stopwatch <on|off|15|30|45|60>, stopwatchpos <0-3>
                  gametime <on|off|15|30|45|60>, gametimepos <0-3>
                  magnifier <on|off|small|medium|large>, magnification <15|2|4>, magnifierpos <0-4>
                  alignment <on|off>, hawkeye <on|off|0-3|small|medium|large|0-3pos>
                  hawkeyelevel <0-3>, hawkeyesize <small|medium|large>, hawkeyepos <0-3>
                  hawkeyenightvision <0-4>

    OPTIONS
      --display N   Target display index from `list` (default: the target monitor)
      --json        Machine-readable output where supported
    """)
    exit(2)
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(code)
}

var displayIndex: Int? = nil
var positional: [String] = []
do {
    var remaining = arguments[...]
    while let argument = remaining.popFirst() {
        if argument == "--display" {
            // Consume the value too, so `--display 1 status` keeps `status`
            // as the command instead of treating `1` as one.
            guard let value = remaining.popFirst(), let index = Int(value) else {
                fail("--display requires a numeric index from `list`")
            }
            displayIndex = index
        } else if !argument.hasPrefix("--") {
            positional.append(argument)
        }
    }
}

func selectedDescriptor() -> DisplayDescriptor {
    let displays = DisplayDiscovery.onlineDisplays()
    if let index = displayIndex {
        guard index >= 0, index < displays.count else {
            fail("display index \(index) out of range (found \(displays.count))")
        }
        return displays[index]
    }
    if let target = displays.first(where: { $0.isTargetModel }) { return target }
    guard let first = displays.first else { fail("no displays are online") }
    return first
}

func controller() -> MonitorController {
    let descriptor = selectedDescriptor()
    guard let controller = MonitorController.connect(descriptor) else {
        fail("no DDC/CI channel for '\(descriptor.label)'. Is it connected over DP/USB-C?")
    }
    return controller
}

func pct(_ reading: DisplaySnapshot.Reading) -> String {
    guard reading.available else { return "n/a" }
    let value = reading.maximum > 0
        ? Int((Double(reading.value) / Double(reading.maximum) * 100).rounded())
        : reading.value
    return "\(value)% (\(reading.value)/\(reading.maximum))"
}

guard let command = positional.first else { usage() }

switch command {
case "audio":
    do {
        let action = positional.dropFirst().first ?? "status"
        let devices = SystemAudio.endpoints()
        let proxy = devices.first(where: \.isTitanArmyAudio)
        switch action {
        case "status":
            var data: [String: Any] = ["endpoints": devices.map { endpoint in
                var item: [String: Any] = ["id": endpoint.id, "uid": endpoint.uid, "name": endpoint.name,
                                          "alive": endpoint.isAlive, "channels": endpoint.outputChannels,
                                          "default": endpoint.id == SystemAudio.defaultOutputID(),
                                          "systemDefault": endpoint.id == SystemAudio.defaultOutputID(systemSounds: true)]
                if let volume = SystemAudio.volume(endpoint.id) { item["volume"] = volume }
                if endpoint.isTitanArmyAudio { item["targetUID"] = SystemAudio.targetUID(endpoint.id) ?? ""; item["muted"] = SystemAudio.muted(endpoint.id); item["diagnostics"] = SystemAudio.diagnostics(endpoint.id) ?? [:] }
                return item
            }]
            data["enabled"] = SystemAudio.preferences.bool(forKey: "enabled")
            let json = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: json, as: UTF8.self))
        case "enable":
            let descriptor = selectedDescriptor()
            let target = try SystemAudio.matchingDisplay(descriptor.label, in: devices)
            guard let proxy else { throw AudioRoutingError.driverMissing }
            try SystemAudio.setTargetUID(target.uid, on: proxy.id)
            for _ in 0..<50 {
                if SystemAudio.uint(proxy.id, kAudioDevicePropertyDeviceIsAlive) == 1 { break }
                Thread.sleep(forTimeInterval: 0.1)
            }
            guard SystemAudio.uint(proxy.id, kAudioDevicePropertyDeviceIsAlive) == 1 else { throw AudioRoutingError.routeNotReady }
            try SystemAudio.enable(for: target)
            print("System volume enabled for \(descriptor.label). Hardware volume was not changed.")
        case "disable":
            try SystemAudio.disable()
            print("Previous sound outputs restored.")
        case "volume":
            guard positional.count >= 3, let value = Float(positional[2]), value.isFinite, (0...100).contains(value), let proxy else { fail("audio volume requires an installed component and a value from 0 to 100") }
            try SystemAudio.setVolume(value / 100, on: proxy.id)
            print("System volume: \(Int(value))%")
        case "mute":
            guard positional.count >= 3, ["on", "off"].contains(positional[2]), let proxy else { fail("audio mute requires an installed component and on or off") }
            try SystemAudio.setMuted(positional[2] == "on", on: proxy.id)
            print("System mute: \(positional[2])")
        default: usage()
        }
    } catch { fail(error.localizedDescription) }
case "list":
    let displays = DisplayDiscovery.onlineDisplays()
    if displays.isEmpty { print("No displays online.") }
    for (index, d) in displays.enumerated() {
        let target = d.isTargetModel ? "  <- target model" : ""
        print(String(
            format: "[%d] %@  %dx%d@%.1fHz  vendor %@ model 0x%04X  EDID %@%@",
            index, d.label, d.widthPixels, d.heightPixels, d.refreshRate,
            d.manufacturer.isEmpty ? "?" : d.manufacturer, d.modelNumber, d.edidUUID ?? "?",
            target
        ))
    }

case "status":
    let c = controller()
    let snap = c.snapshot(thorough: true)
    print("Display   : \(c.descriptor.label)")
    print("Link      : \(c.descriptor.widthPixels)x\(c.descriptor.heightPixels) @ \(c.descriptor.refreshRate) Hz")
    print("EDID      : \(c.descriptor.manufacturer)  model 0x\(String(format: "%04X", c.descriptor.modelNumber))")
    print("DDC path  : \(c.session.endpoint.servicePath)")
    print("HDR       : \(snap.hdrEnabled.map { $0 ? "ON (brightness locked)" : "off" } ?? "unknown")")
    print("Brightness: \(pct(snap.brightness))")
    print("Contrast  : \(pct(snap.contrast))")
    print("Volume    : \(pct(snap.volume))")
    print("Pic mode  : \(snap.pictureMode.available ? "\(snap.pictureMode.value)" : "n/a")")
    print("Overdrive : \(snap.overdrive.available ? "\(snap.overdrive.value)/\(snap.overdrive.maximum)" : "n/a")")
    print("ScreenMode: \(snap.screenMode.available ? "\(snap.screenMode.value)/\(snap.screenMode.maximum)" : "n/a")")
    print("VendorHDR : \(snap.vendorHDR.available ? "\(snap.vendorHDR.value)/\(snap.vendorHDR.maximum)" : "n/a")")

case "probe":
    let c = controller()
    print("Probing VCP 0x00-0xFF on '\(c.descriptor.label)' (3 stable reads each)\n")
    var found: [UInt8] = []
    for code in UInt8(0)...UInt8(255) {
        guard let first = c.session.probe(code), first.result == .success else { continue }
        // Require two more identical reads to reject the counterfeits this panel
        // emits for unimplemented codes.
        var stable = true
        for _ in 0..<2 {
            guard let again = c.session.probe(code),
                  again.maximum == first.maximum,
                  again.current == first.current else { stable = false; break }
        }
        guard stable else { continue }
        found.append(code)
        print(String(
            format: "  0x%02X  %-22@ max=%-5d cur=%-5d %@",
            code, VCPName.of(code) as NSString, first.maximum, first.current,
            first.isContinuous ? "continuous" : "enum"
        ))
    }
    print("\n\(found.count) stable VCPs: "
        + found.map { String(format: "%02X", $0) }.joined(separator: " "))

case "set":
    guard positional.count >= 3 else { usage() }
    let codeText = positional[1].hasPrefix("0x")
        ? String(positional[1].dropFirst(2)) : positional[1]
    guard let code = UInt8(codeText, radix: 16), let value = UInt16(positional[2]) else {
        fail("expected: set <hex vcp> <value>")
    }
    let c = controller()
    do {
        // Same guard as every other write path: unknown and refuted registers
        // are never written.
        let reply = try c.writeVendorValue(vcp: code, value: value)
        print(String(format: "0x%02X (%@) = %d  [verified]", code, VCPName.of(code), reply.current))
    } catch {
        fail((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }

case "brightness", "contrast", "volume":
    guard positional.count >= 2, let percent = Int(positional[1]) else { usage() }
    let c = controller()
    do {
        switch command {
        case "brightness":
            try c.setStandardTone(percent: percent, register: .brightness)
        case "contrast":
            try c.setStandardTone(percent: percent, register: .contrast)
        default: try c.setVolume(percent: percent)
        }
        let snap = c.snapshot()
        let reading = command == "brightness" ? snap.brightness
            : command == "contrast" ? snap.contrast : snap.volume
        print("\(command) = \(pct(reading))")
    } catch {
        fail((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }

case "scene":
    guard positional.count >= 2 else { usage() }
    let c = controller()
    let map: [String: TitanArmyProfile.SceneMode] = [
        "standard": .standard, "rtsrpg": .rtsRpg, "fps": .fps, "moba": .moba,
        "movie": .movie, "reading": .reading, "night": .night, "eyecare": .eyeCare,
        "macview": .macView, "ebook": .eBook, "srgb": .sRGB, "adobe": .adobeRGB,
        "dcip3": .dciP3, "dydsfps": .dyDsULLFPS, "dydsld": .dyDsLocalDimming,
        "custom": .custom,
    ]
    guard let mode = map[positional[1].lowercased()] else { usage() }
    do {
        try c.setSceneMode(mode)
        print(String(format: "Scene = %@ [official protocol accepted]", mode.title))
    } catch {
        fail((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }

case "colortemp":
    guard positional.count >= 2 else { usage() }
    let map: [String: TitanArmyProfile.ColorTemperature] = [
        "warm": .warm, "natural": .natural, "cold": .cold,
        "user1": .user1, "user2": .user2, "user3": .user3,
    ]
    guard let mode = map[positional[1].lowercased()] else { usage() }
    let c = controller()
    do {
        try c.setColorTemperature(mode)
        print("Color temperature = \(mode.title) [official protocol accepted]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "nightvision", "dynamicod", "sharpness", "lowbluelight":
    guard positional.count >= 2, let raw = UInt16(positional[1]), raw <= 4 else { usage() }
    let c = controller()
    do {
        switch command {
        case "nightvision":
            guard let level = TitanArmyProfile.NightVisionLevel(rawValue: raw) else { throw DDCError.noValidReply(vcp: 0) }
            try c.setNightVision(level); print("Night vision = \(level.title) [official protocol accepted]")
        case "dynamicod":
            guard let level = TitanArmyProfile.DynamicOverdriveLevel(rawValue: raw) else { throw DDCError.noValidReply(vcp: 0) }
            try c.setDynamicOverdrive(level); print("Dynamic OD = \(level.title) [official protocol accepted]")
        case "sharpness":
            guard let level = TitanArmyProfile.SharpnessLevel(rawValue: raw) else { throw DDCError.noValidReply(vcp: 0) }
            try c.setSharpness(level); print("Sharpness = \(level.title) [official protocol accepted]")
        default:
            guard let level = TitanArmyProfile.LowBlueLightLevel(rawValue: raw) else { throw DDCError.noValidReply(vcp: 0) }
            try c.setLowBlueLight(level); print("Low blue light = \(level.title) [official protocol accepted]")
        }
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "dydsull":
    guard positional.count >= 2 else { usage() }
    let value = positional[1].lowercased() == "off" ? 2 : (UInt16(positional[1]) ?? 0)
    guard let level = TitanArmyProfile.DyDsULLLevel(rawValue: value), value >= 2, value <= 8 else { usage() }
    let c = controller()
    do {
        try c.setDyDsULL(level)
        print("DyDs / ULL = \(level.title) [official protocol accepted]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "adaptivesync":
    guard positional.count >= 2, ["on", "off"].contains(positional[1].lowercased()) else { usage() }
    let c = controller()
    do {
        try c.setAdaptiveSync(positional[1].lowercased() == "on")
        print("Adaptive-Sync = \(positional[1].lowercased()) [official protocol accepted]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "gammavendor":
    guard positional.count >= 2, let raw = UInt16(positional[1]),
          let mode = TitanArmyProfile.OfficialGamma(rawValue: raw) else { usage() }
    let c = controller()
    do {
        try c.setOfficialGamma(mode)
        print("Official gamma = \(mode.title) [official call site]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "gamerush":
    guard positional.count >= 2, ["on", "off"].contains(positional[1].lowercased()) else { usage() }
    let c = controller()
    do {
        try c.setGameRush(positional[1].lowercased() == "on")
        print("Game Rush = \(positional[1].lowercased()) [official call site]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "enhance":
    guard positional.count >= 3, let value = Int(positional[2]),
          let enhancement = [
              "color": TitanArmyProfile.Enhancement.colorEnhance,
              "cr": .crEnhance,
              "shadow": .shadowBalance,
              "sr": .superResolution,
              "halo": .haloControl,
          ][positional[1].lowercased()] else { usage() }
    guard enhancement.allowedRange.contains(value) else {
        fail("value must be in \(enhancement.allowedRange.lowerBound)...\(enhancement.allowedRange.upperBound)")
    }
    let c = controller()
    do {
        try c.setEnhancement(enhancement, value: value)
        print("\(enhancement.title) = \(value) [official call site]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "outputrange":
    guard positional.count >= 2,
          let range = [
              "auto": TitanArmyProfile.RGBOutputRange.auto,
              "limited": .limited,
              "full": .full,
          ][positional[1].lowercased()] else { usage() }
    let c = controller()
    do {
        try c.setRGBOutputRange(range)
        print("RGB output range = \(range.title) [official call site]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "custom":
    guard positional.count >= 3, let value = Int(positional[2]),
          let target = [
              "saturation": TitanArmyProfile.CustomSceneTarget.saturation,
              "gamma": .gamma,
              "hue": .hue,
              "nightvision": .nightVision,
              "od": .dynamicOverdrive,
              "cr": .crEnhance,
              "color": .colorEnhance,
          ][positional[1].lowercased()] else { usage() }
    guard target.allowedRange.contains(value) else {
        fail("value must be in \(target.allowedRange.lowerBound)...\(target.allowedRange.upperBound)")
    }
    let c = controller()
    do {
        try c.setCustomScene(target, value: value)
        print("Custom \(target.windowsSetting.rawValue) = \(value) [official call site]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

case "hdr":
    let c = controller()
    let action = positional.count >= 2 ? positional[1] : "status"
    switch action {
    case "on", "off":
        let want = action == "on"
        let ok = c.setSystemHDR(enabled: want)
        print("HDR \(want ? "on" : "off"): \(ok ? "confirmed" : "NOT confirmed")")
    default:
        print("HDR: \(c.hdrEnabled.map { $0 ? "on" : "off" } ?? "unknown")")
    }

case "od":
    guard positional.count >= 2 else { usage() }
    let map: [String: TitanArmyProfile.Overdrive] = [
        "off": .off, "normal": .normal, "fast": .fast, "fastest": .fastest,
    ]
    guard let level = map[positional[1].lowercased()] else { usage() }
    let c = controller()
    do {
        try c.setOverdrive(level)
        print("Overdrive = \(level.title) [verified]")
    } catch {
        fail((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }

case "vendorhdr":
    guard positional.count >= 2 else { usage() }
    let map: [String: TitanArmyProfile.VendorHDR] = [
        "off": .off, "auto": .auto, "game": .game, "movie": .movie,
    ]
    guard let mode = map[positional[1].lowercased()] else { usage() }
    let c = controller()
    do {
        try c.setVendorHDR(mode)
        print("Vendor HDR mode = \(mode.title) [official protocol]")
    } catch {
        fail((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }

case "localdimming":
    guard positional.count >= 2 else { usage() }
    let map: [String: TitanArmyProfile.LocalDimming] = [
        "off": .off, "low": .low, "smooth": .smooth, "medium": .medium, "high": .high,
    ]
    guard let level = map[positional[1].lowercased()] else { usage() }
    let c = controller()
    do {
        try c.setLocalDimming(level)
        print("Local Dimming = \(level.title) [protocol accepted]")
    } catch {
        fail((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }

case "monitorhdr":
    guard positional.count >= 2 else { usage() }
    let map: [String: TitanArmyProfile.VendorHDR] = [
        "off": .off, "auto": .auto, "game": .game, "movie": .movie,
    ]
    guard let mode = map[positional[1].lowercased()] else { usage() }
    let c = controller()
    do {
        try c.setVendorHDR(mode)
        print("Monitor HDR = \(mode.title) [protocol accepted]")
    } catch {
        fail((error as? LocalizedError)?.errorDescription ?? "\(error)")
    }

case "assistant":
    guard positional.count >= 3 else { usage() }
    let action = positional[1].lowercased()
    let argument = positional[2].lowercased()
    func bool(_ on: Bool) -> TitanArmyProfile.Toggle { TitanArmyProfile.Toggle(on) }
    let c = controller()
    do {
        switch action {
        case "screen":
            let map: [String: TitanArmyProfile.GameAssistant.ScreenSize] = [
                "full": .fullGame, "wide": .wide, "25": .inch25, "27": .inch27, "32": .inch32,
            ]
            guard let mode = map[argument] else { usage() }
            try c.setGameAssistant(.screenSize(mode))
        case "refreshpos":
            guard let raw = UInt16(argument), let mode = TitanArmyProfile.GameAssistant.RefreshPosition(rawValue: raw) else { usage() }
            try c.setGameAssistant(.refreshPosition(mode))
        case "crosshair":
            if argument == "on" || argument == "off" {
                try c.setGameAssistant(.crosshair(bool(argument == "on")))
            } else if let raw = UInt16(argument), let shape = TitanArmyProfile.GameAssistant.CrosshairShape(rawValue: raw) {
                try c.setGameAssistant(.crosshair(.on))
                try c.setGameAssistant(.crosshairShape(shape))
            } else { usage() }
        case "crosshaircolor":
            let map: [String: TitanArmyProfile.GameAssistant.CrosshairColor] = [
                "red": .red, "yellow": .yellow, "green": .green, "cyan": .cyan,
                "blue": .blue, "purple": .purple, "white": .white, "auto": .automatic,
            ]
            guard let mode = map[argument] else { usage() }
            try c.setGameAssistant(.crosshairColor(mode))
        case "stopwatch", "gametime":
            let isStopwatch = action == "stopwatch"
            if argument == "on" || argument == "off" {
                let state = bool(argument == "on")
                if isStopwatch { try c.setGameAssistant(.stopwatch(state)) }
                else { try c.setGameAssistant(.gameTime(state)) }
            } else if let duration = [
                "15": TitanArmyProfile.GameAssistant.Duration.minutes15,
                "30": .minutes30, "45": .minutes45, "60": .minutes60,
            ][argument] {
                if isStopwatch { try c.setGameAssistant(.stopwatchTime(duration)) }
                else { try c.setGameAssistant(.gameTimeValue(duration)) }
            } else { usage() }
        case "stopwatchpos", "gametimepos":
            guard let raw = UInt16(argument), let mode = TitanArmyProfile.GameAssistant.Position(rawValue: raw) else { usage() }
            if action == "stopwatchpos" { try c.setGameAssistant(.stopwatchPosition(mode)) }
            else { try c.setGameAssistant(.gameTimePosition(mode)) }
        case "magnifier":
            if argument == "on" || argument == "off" {
                try c.setGameAssistant(.magnifier(bool(argument == "on")))
            } else {
                let map: [String: TitanArmyProfile.GameAssistant.MagnifierSize] = [
                    "small": .small, "medium": .medium, "large": .large,
                ]
                guard let mode = map[argument] else { usage() }
                try c.setGameAssistant(.magnifierSize(mode))
            }
        case "magnification":
            let map: [String: TitanArmyProfile.GameAssistant.Magnification] = ["15": .x15, "2": .x2, "4": .x4]
            guard let mode = map[argument] else { usage() }
            try c.setGameAssistant(.magnification(mode))
        case "magnifierpos":
            guard let raw = UInt16(argument), let mode = TitanArmyProfile.GameAssistant.MagnifierPosition(rawValue: raw) else { usage() }
            try c.setGameAssistant(.magnifierPosition(mode))
        case "alignment":
            guard ["on", "off"].contains(argument) else { usage() }
            try c.setGameAssistant(.alignment(bool(argument == "on")))
        case "hawkeye":
            if argument == "on" || argument == "off" {
                try c.setGameAssistant(.hawkEye(bool(argument == "on")))
            } else if let level = [
                "0": TitanArmyProfile.GameAssistant.HawkEyeLevel.off,
                "1": .level1, "2": .level2, "3": .level3,
            ][argument] {
                try c.setGameAssistant(.hawkEyeLevel(level))
            } else if ["small", "medium", "large"].contains(argument) {
                let size = [
                    "small": TitanArmyProfile.GameAssistant.MagnifierSize.small,
                    "medium": .medium, "large": .large,
                ][argument]!
                try c.setGameAssistant(.hawkEyeSize(size))
            } else if let raw = UInt16(argument), let position = TitanArmyProfile.GameAssistant.Position(rawValue: raw) {
                try c.setGameAssistant(.hawkEyePosition(position))
            } else { usage() }
        case "hawkeyelevel":
            let map: [String: TitanArmyProfile.GameAssistant.HawkEyeLevel] = ["0": .off, "1": .level1, "2": .level2, "3": .level3]
            guard let level = map[argument] else { usage() }
            try c.setGameAssistant(.hawkEyeLevel(level))
        case "hawkeyesize":
            let map: [String: TitanArmyProfile.GameAssistant.MagnifierSize] = ["small": .small, "medium": .medium, "large": .large]
            guard let size = map[argument] else { usage() }
            try c.setGameAssistant(.hawkEyeSize(size))
        case "hawkeyepos":
            guard let raw = UInt16(argument), let position = TitanArmyProfile.GameAssistant.Position(rawValue: raw) else { usage() }
            try c.setGameAssistant(.hawkEyePosition(position))
        case "hawkeyenightvision", "assistantnightvision":
            guard let raw = UInt16(argument), let level = TitanArmyProfile.NightVisionLevel(rawValue: raw) else { usage() }
            try c.setGameAssistant(.nightVision(level))
        default:
            usage()
        }
        print("Game Assistant = \(action) \(argument) [official call site]")
    } catch { fail((error as? LocalizedError)?.errorDescription ?? "\(error)") }

default:
    usage()
}
