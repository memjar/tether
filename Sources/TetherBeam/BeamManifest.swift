import Foundation

public struct BeamManifest {
    public init() {}

    public func plist(for build: BeamBuild, baseURL: String) -> String {
        let ipaURL = "\(baseURL)/builds/\(build.id.uuidString)/download"
        let title = "\(build.name) \(build.version) (\(build.build))"
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>items</key>
            <array>
                <dict>
                    <key>assets</key>
                    <array>
                        <dict>
                            <key>kind</key><string>software-package</string>
                            <key>url</key><string>\(ipaURL)</string>
                        </dict>
                    </array>
                    <key>metadata</key>
                    <dict>
                        <key>bundle-identifier</key><string>\(build.bundleId)</string>
                        <key>bundle-version</key><string>\(build.version)</string>
                        <key>kind</key><string>software</string>
                        <key>title</key><string>\(title)</string>
                    </dict>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }

    public func installURL(for build: BeamBuild, baseURL: String) -> String {
        let manifestURL = "\(baseURL)/builds/\(build.id.uuidString)/manifest.plist"
        return "itms-services://?action=download-manifest&url=\(manifestURL)"
    }
}
