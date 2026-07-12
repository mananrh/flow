import Foundation

struct DataWiper {
    static func wipeAllUserData() {
        let fileManager = FileManager.default

        // Application Support directories
        let appSupportPaths = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Flow"),
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Flow Dev")
        ]

        for path in appSupportPaths {
            if let path = path {
                try? fileManager.removeItem(at: path)
            }
        }

        // UserDefaults domains
        let bundleID = Bundle.main.bundleIdentifier ?? "com.mananrathod.flow"
        let domainSuffixes = ["", ".dev"]

        for suffix in domainSuffixes {
            let domain = bundleID + suffix
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
        }
    }
}