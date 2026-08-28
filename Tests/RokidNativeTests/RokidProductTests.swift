@main
struct RokidProductTests {
    static func main() {
        precondition(AppLanguage.simplifiedChinese.localizationCode == "zh-Hans")
        precondition(AppLanguage.english.localizationCode == "en")
        precondition(RokidProduct.glasses.scrcpyVideoArguments == [])
        precondition(
            RokidProduct.lite.scrcpyVideoArguments
                == ["--display-id=2", "--crop=1920:1200:0:0"]
        )
        precondition(
            RokidProduct.studio.scrcpyVideoArguments
                == ["--display-id=2", "--crop=1920:1200:0:0"]
        )
        precondition(
            ADBDevice(
                serial: "lite",
                state: "device",
                model: "RG_station2",
                product: "station2",
                isUSB: false
            ).rokidProduct == .lite
        )
        precondition(
            ADBDevice(
                serial: "studio",
                state: "device",
                model: "RG-stationPro",
                product: "stationPro",
                isUSB: false
            ).rokidProduct == .studio
        )
    }
}
