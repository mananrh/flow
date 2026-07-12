import Foundation

struct DataWiper {
    static func wipeAllUserData() {
        let fileManager = FileManager.default
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Flow"
        let bundleID = Bundle.main.bundleIdentifier ?? "com.mananrathod.flow"

        // Application Support directory
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: appSupport.appendingPathComponent(appName))
        }

        // UserDefaults domain
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()
    }
}