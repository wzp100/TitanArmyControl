import Foundation
import XCTest
@testable import TitanArmyCore

final class SharedContractTests: XCTestCase {
    private var root: [String: Any]!

    override func setUpWithError() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repository.appending(path: "shared/profile.contract.json")
        let data = try Data(contentsOf: url)
        root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    func testModelAndStandardVCPsMatchContract() throws {
        let model = try XCTUnwrap(root["model"] as? [String: Any])
        XCTAssertEqual(model["name"] as? String, TitanArmyProfile.modelName)

        let standard = try XCTUnwrap(root["standardVcp"] as? [String: Any])
        XCTAssertEqual(hex(standard["brightness"]), VCPCode.brightness)
        XCTAssertEqual(hex(standard["contrast"]), VCPCode.contrast)
        XCTAssertEqual(hex(standard["gamma"]), VCPCode.gamma)
        XCTAssertEqual(hex(standard["redGain"]), VCPCode.redGain)
        XCTAssertEqual(hex(standard["greenGain"]), VCPCode.greenGain)
        XCTAssertEqual(hex(standard["blueGain"]), VCPCode.blueGain)
        XCTAssertEqual(hex(standard["volume"]), VCPCode.volume)
        XCTAssertEqual(hex(standard["mute"]), VCPCode.mute)
        XCTAssertEqual(hex(standard["inputSource"]), VCPCode.inputSource)
    }

    func testOfficialSettingsAndScenesMatchContract() throws {
        let official = try XCTUnwrap(root["officialSettings"] as? [String: Any])
        for setting in TitanArmyProfile.WindowsSetting.allCases {
            let entry = try XCTUnwrap(
                official[setting.rawValue] as? [String: Any],
                "Missing contract entry for \(setting.rawValue)"
            )
            XCTAssertEqual(hex(entry["register"]), setting.register)

            let range = try XCTUnwrap(entry["range"] as? [Int])
            XCTAssertEqual(range, [setting.allowedRange.lowerBound, setting.allowedRange.upperBound])
        }

        let scenes = try XCTUnwrap(root["sceneModes"] as? [String: Int])
        XCTAssertEqual(scenes["standard"], Int(TitanArmyProfile.SceneMode.standard.rawValue))
        XCTAssertEqual(scenes["fps"], Int(TitanArmyProfile.SceneMode.fps.rawValue))
        XCTAssertEqual(scenes["custom"], Int(TitanArmyProfile.SceneMode.custom.rawValue))
    }

    private func hex(_ value: Any?) -> UInt8? {
        guard let text = value as? String else { return nil }
        return UInt8(text.dropFirst(2), radix: 16)
    }
}
