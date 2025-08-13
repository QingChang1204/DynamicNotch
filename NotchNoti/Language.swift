//
//  Language.swift
//  NotchNoti
//
//  Created by 秋星桥 on 2024/7/31.
//

import Cocoa

enum Language: String, CaseIterable, Identifiable, Codable {
    case system = "Follow System"
    case english = "English"
    case german = "German"
    case simplifiedChinese = "Simplified Chinese"
    case traditionalChinese = "Traditional Chinese"
		case japanese = "Japanese"

    var id: String { rawValue }

    var localized: String {
        NSLocalizedString(rawValue, comment: "")
    }

    func apply() {
        let languageCode: String?

        switch self {
        case .system:
            // 首先获取系统的首选语言
            let preferredLanguages = Locale.preferredLanguages
            if let firstLanguage = preferredLanguages.first {
                // 检查系统语言
                if firstLanguage.hasPrefix("zh-Hans") || firstLanguage.hasPrefix("zh_CN") {
                    languageCode = "zh-Hans"
                } else if firstLanguage.hasPrefix("zh-Hant") || firstLanguage.hasPrefix("zh_TW") || firstLanguage.hasPrefix("zh_HK") {
                    languageCode = "zh-Hant"
                } else if firstLanguage.hasPrefix("ja") {
                    languageCode = "ja"
                } else if firstLanguage.hasPrefix("de") {
                    languageCode = "de"
                } else if firstLanguage.hasPrefix("en") {
                    languageCode = "en"
                } else {
                    // 如果不是支持的语言，尝试根据语言代码前缀匹配
                    if firstLanguage.hasPrefix("zh") {
                        // 对于其他中文变体，根据地区判断
                        let locale = Locale.current
                        let region = locale.regionCode
                        if region == "TW" || region == "HK" || region == "MO" {
                            languageCode = "zh-Hant"
                        } else {
                            languageCode = "zh-Hans"
                        }
                    } else {
                        // 默认使用英文
                        languageCode = "en"
                    }
                }
            } else {
                // 如果无法获取系统语言，默认使用英文
                languageCode = "en"
            }
        case .english:
            languageCode = "en"
        case .german:
            languageCode = "de"
        case .simplifiedChinese:
            languageCode = "zh-Hans"
        case .traditionalChinese:
            languageCode = "zh-Hant"
				case .japanese:
						languageCode = "ja"
        }

        Bundle.setLanguage(languageCode)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSAlert.popRestart(
                NSLocalizedString("The language has been changed. The app will restart for the changes to take effect.", comment: ""),
                completion: restartApp
            )
        }
    }
}

private func restartApp() {
    guard let appPath = Bundle.main.executablePath else { return }
    NSApp.terminate(nil)

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: appPath)
        try? process.run()
        exit(0)
    }
}

private extension Bundle {
    private static var onLanguageDispatchOnce: () -> Void = {
        object_setClass(Bundle.main, PrivateBundle.self)
    }

    static func setLanguage(_ language: String?) {
        onLanguageDispatchOnce()

        if let language {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}

private class PrivateBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
              let languageCode = languages.first,
              let bundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: bundlePath)
        else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}
