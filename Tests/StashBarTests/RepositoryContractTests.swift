import Foundation
import Testing

struct RepositoryContractTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func read(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    @Test func requiredProjectFilesExist() {
        for path in [
            "README.md",
            "README.zh-CN.md",
            "CHANGELOG.md",
            "LICENSE",
            "Makefile",
            "Package.swift",
            "Resources/Info.plist",
            ".github/workflows/ci.yml",
        ] {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), "Missing required file: \(path)")
        }
    }

    @Test func bundleVersionMatchesCurrentReleaseDocumentation() throws {
        let plistData = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        let shortVersion = try #require(plist?["CFBundleShortVersionString"] as? String)
        let bundleVersion = try #require(plist?["CFBundleVersion"] as? String)

        #expect(shortVersion == "2.0.3")
        #expect(bundleVersion == shortVersion)
        #expect(try read("README.md").contains("Current source release: `v\(shortVersion)`"))
        #expect(try read("README.zh-CN.md").contains("当前源码版本：`v\(shortVersion)`"))
        #expect(try read("CHANGELOG.md").contains("## \(shortVersion) -"))
    }

    @Test func readmesLinkRequiredLocalMetadata() throws {
        for path in ["README.md", "README.zh-CN.md"] {
            let readme = try read(path)
            #expect(readme.contains("CHANGELOG.md"), "\(path) must link release history")
            #expect(readme.contains("LICENSE"), "\(path) must link license")
            #expect(readme.contains("docs/closed.png"), "\(path) must embed the menu-bar screenshot")
        }
    }

    @Test func signingDocsMatchScriptBehavior() throws {
        let script = try read("build_app.sh")
        let english = try read("README.md")
        let chinese = try read("README.zh-CN.md")

        #expect(script.contains("fallback: stable identity not found"))
        #expect(script.contains("fallback: stable identity exists but codesign could not use it"))
        #expect(english.contains("If a local code-signing identity named `StashBar Local Dev` already exists"))
        #expect(english.contains("cannot be used by the"))
        #expect(chinese.contains("如果登录钥匙串里已经有名为 `StashBar Local Dev` 的本地签名身份"))
        #expect(chinese.contains("无法使用它"))
        #expect(!english.contains("created\nonce"))
        #expect(!chinese.contains("自动在你的登录钥匙串里创建"))
    }

    @Test func continuousIntegrationRunsCoreChecks() throws {
        let workflow = try read(".github/workflows/ci.yml")
        #expect(workflow.contains("swift test"))
        #expect(workflow.contains("swift build -c release"))
        #expect(workflow.contains("STASHBAR_PACKAGE_ONLY=1 ./build_app.sh"))
        #expect(workflow.contains("codesign --verify --deep --strict dist/StashBar.app"))
        #expect(workflow.contains("macos-"))
    }

    @Test func packageOnlyBuildDoesNotInstallOrLaunch() throws {
        let script = try read("build_app.sh")
        let makefile = try read("Makefile")
        let english = try read("README.md")
        let chinese = try read("README.zh-CN.md")

        #expect(script.contains("STASHBAR_PACKAGE_ONLY"))
        #expect(script.contains("Package-only build complete"))
        #expect(makefile.contains("package:"))
        #expect(makefile.contains("STASHBAR_PACKAGE_ONLY=1 ./build_app.sh"))
        #expect(english.contains("make package"))
        #expect(chinese.contains("make package"))
    }
}
