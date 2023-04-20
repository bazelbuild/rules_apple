import Foundation

public final class TestAction {
    public struct Input {
        let testBundle: URL
        let testHost: URL?
        let createXcresultBundle: Bool
        let deviceType: String
        let osVersion: String
        let simulatorCreator: URL
        let random: Bool
        let xcodebuildArgs: [String]
        let xctestrunTemplate: URL
        let reuseSimulator: Bool
        let testEnv: String?
        let testType: String
        let simulatorName: String?
        let testFilter: String?
        let testCoverageManifest: URL?

        public init(
            testBundle: URL,
            testHost: URL?,
            createXcresultBundle: Bool,
            deviceType: String,
            osVersion: String,
            simulatorCreator: URL,
            random: Bool,
            xcodebuildArgs: [String],
            xctestrunTemplate: URL,
            reuseSimulator: Bool,
            testEnv: String?,
            testType: String,
            simulatorName: String?,
            testFilter: String?,
            testCoverageManifest: URL?
        ) {
            self.testBundle = testBundle
            self.testHost = testHost
            self.createXcresultBundle = createXcresultBundle
            self.deviceType = deviceType
            self.osVersion = osVersion
            self.simulatorCreator = simulatorCreator
            self.random = random
            self.xcodebuildArgs = xcodebuildArgs.cleanedUpArgument
            self.xctestrunTemplate = xctestrunTemplate
            self.reuseSimulator = reuseSimulator
            self.testEnv = testEnv?.cleanedUpArgument
            self.testType = testType
            self.simulatorName = simulatorName?.cleanedUpArgument
            self.testFilter = testFilter?.cleanedUpArgument
            self.testCoverageManifest = testCoverageManifest
        }
    }

    private let interactor: InteractorProtocol

    public convenience init() {
        self.init(
            interactor: Interactor.shared
        )
    }

    init(
        interactor: InteractorProtocol
    ) {
        self.interactor = interactor
    }

    public func execute(input: Input) throws {
        do {
            try run(input: input)
        } catch {
            // Possible error customization point
            throw error
        }
    }
}

private extension TestAction {
    func run(input: Input) throws {
        if interactor.env["DEBUG_XCTESTRUNNER"] != nil {
            interactor.verbose = true
        }

        guard interactor.env["DEVELOPER_DIR"] != nil else {
            throw TestRunnerError.missingDeveloperDir
        }

        let bundlePath = input.testBundle
        let hostPath = input.testHost

        interactor.tmpDir = try getTmpDir()
        try prepare(bundlePath: input.testBundle)

        try prepare(hostPath: hostPath)

        let (xctestrunEnv, passthroughEnv) = try prepareEnv(testEnv: input.testEnv, hostPath: hostPath)
        let sanitizerDyldEnv = try prepareSanitizerDyldEnv(bundlePath: bundlePath)

        let xcrunTargetAppPath = prepareXcrunTargetAppPath(hostPath: hostPath, testType: input.testType)
        let xctestrunHostPath = try prepareXctestrunHostPath(hostPath: hostPath, testType: input.testType)

        let xctestrunLibraries = prepareXctestrunLibraries(sanitizerDyldEnv: sanitizerDyldEnv)
        let (xctestrunOnlyTestSection, xctestrunSkipTestSection) = prepareXctestrunTestFilters(
            testFilter: input.testFilter
        )

        let shouldUseXcodebuild = shouldUseXcodebuild(
            hostPath: hostPath,
            random: input.random,
            createXcresultBundle: input.createXcresultBundle,
            xctestrunSkipTestSection: xctestrunSkipTestSection,
            xctestrunOnlyTestSection: xctestrunOnlyTestSection,
            xcodebuildArgs: input.xcodebuildArgs
        )
        let profraw = interactor.tmpDir + "coverage.profraw"
        let testlog = interactor.tmpDir + "test.log"
        let simulatorId = try prepareSimulator(input: input)
        let intelSimulatorHack = try needsIntelSimulatorHack(bundlePath: bundlePath)

        if shouldUseXcodebuild {
            if hostPath == nil, intelSimulatorHack {
                throw TestRunnerError.missingTestHostWhenUsingIntelHack
            }

            let replacements: [String: String] = [
                "BAZEL_INSERT_LIBRARIES": xctestrunLibraries,
                "BAZEL_TEST_BUNDLE_PATH": "__TESTROOT__/\(bundlePath.name).xctest",
                "BAZEL_TEST_ENVIRONMENT": xctestrunEnv,
                "BAZEL_TEST_HOST_BASED": (hostPath != nil).description,
                "BAZEL_TEST_HOST_PATH": xctestrunHostPath,
                "BAZEL_TEST_PRODUCT_MODULE_NAME": bundlePath.name.replacingOccurrences(of: "-", with: "_"),
                "BAZEL_IS_XCTRUNNER_HOSTED_BUNDLE": (xcrunTargetAppPath != nil).description,
                "BAZEL_IS_UI_TEST_BUNDLE": (xcrunTargetAppPath != nil).description,
                "BAZEL_TARGET_APP_PATH": xcrunTargetAppPath ?? "",
                "BAZEL_TEST_ORDER_STRING": input.random ? "random": "alphabetical",
                "BAZEL_COVERAGE_PROFRAW": profraw.path,
                "BAZEL_COVERAGE_OUTPUT_DIR": interactor.tmpDir.path,
                "BAZEL_SKIP_TEST_SECTION": xctestrunSkipTestSection ?? "",
                "BAZEL_ONLY_TEST_SECTION": xctestrunOnlyTestSection ?? "",
            ]
            let xctestrunFile = try prepareXctestrunFile(
                replacements: replacements,
                templatePath: input.xctestrunTemplate
            )
            let args = try makeXcodebuildArgs(input: input, simulatorId: simulatorId, xctestrunFile: xctestrunFile)
            try interactor.run("xcodebuild test-without-building \(args) 2>&1 | tee -i \(testlog)")
        } else {
            let platformDeveloperDir = try interactor.getDeveloperDir() + "Platforms/iPhoneSimulator.platform/Developer"
            let xctestBinary = try prepareXctestBinary(
                platformDeveloperDir: platformDeveloperDir,
                intelSimulatorHack: intelSimulatorHack
            )
            try interactor.run(
                """
                SIMCTL_CHILD_DYLD_LIBRARY_PATH='\(platformDeveloperDir)/usr/lib' \
                SIMCTL_CHILD_DYLD_FALLBACK_FRAMEWORK_PATH='\(platformDeveloperDir)/Library/Frameworks' \
                SIMCTL_CHILD_DYLD_INSERT_LIBRARIES='\(sanitizerDyldEnv ?? "")' \
                SIMCTL_CHILD_LLVM_PROFILE_FILE='\(profraw)' \
                env \(passthroughEnv.joined(separator: " ")) \
                xcrun simctl \
                spawn \
                '\(simulatorId)' \
                '\(xctestBinary.path)' \
                -XCTest All \
                '\(interactor.tmpDir.path)/\(bundlePath.name).xctest' \
                2>&1 | tee -i \(testlog)
                """
            )
        }

        if !input.reuseSimulator {
            try interactor.run("xcrun simctl shutdown \(simulatorId)")
            try interactor.run("xcrun simctl delete \(simulatorId)")
        }

        let logs = try interactor.read(testlog)

        if logs.contains("Executed 0 tests, with 0 failures") {
            throw TestRunnerError.emptyTestBundle
        }

        // When tests crash after they have reportedly completed, XCTest marks them as
        // a success. These 2 cases are Swift fatalErrors, and C++ exceptions. There
        // are likely other cases we can add to this in the future. FB7801959
        if [/^Fatal error:/, /^libc++abi.dylib: terminating with uncaught exception/].contains(where: { logs.contains($0) }) {
            throw TestRunnerError.logContainTestFalseNegative
        }

        if interactor.env["COVERAGE"] != nil {
            try prepareCoverage(profraw: profraw, testCoverageManifest: input.testCoverageManifest)
        }
    }
}

private extension TestAction {
    func prepareCoverage(profraw: URL, testCoverageManifest: URL?) throws  {
        let profdata = interactor.tmpDir + "coverage.profdata"
        try interactor.run("xcrun llvm-profdata merge '\(profraw)' --output '\(profdata)'")
        var lcovArgs = [
            "-instr-profile '\(profdata)'",
            "-ignore-filename-regex='.*external/.+'",
            "-path-equivalence='.,\(interactor.currentPath)'"
        ]
        var hasBinary = false
        var arch = try interactor.run("uname -m")
        for binary in try interactor.env["TEST_BINARIES_FOR_LLVM_COV"].unwrap().components(separatedBy: " ") {
            if !hasBinary {
                lcovArgs.append(binary)
                hasBinary = true
                if try !interactor.run("file \(binary)").contains(arch) {
                    arch = "x86_64"
                }
            } else {
                lcovArgs.append("-object \(binary)")
            }

            lcovArgs.append("-arch=\(arch)")
        }

        var llvmCoverageManifest = try interactor.env["COVERAGE_MANIFEST"].unwrap().asPath
        if let testCoverageManifest = testCoverageManifest, interactor.exists(path: testCoverageManifest) {
            llvmCoverageManifest = testCoverageManifest
        }
        let errorFile = interactor.tmpDir + "llvm-cov-error.txt"
        try interactor.run(
            """
            xcrun llvm-cov \
            export \
            -format lcov \
            \(lcovArgs.joined(separator: " ")) \
            @"\(llvmCoverageManifest)" \
            > >(tee '\(try interactor.env["COVERAGE_OUTPUT_FILE"].unwrap())') \
            2> >(tee '\(errorFile)' >&2)
            """
        )

        let errorLog = try interactor.read(errorFile)
        if !errorLog.isEmpty {
            // Error ourselves if lcov outputs warnings, such as if we misconfigure
            // something and the file path of one of the covered files doesn't exist
            throw TestRunnerError.warningsWhenExportingCoverage(try interactor.read(errorFile))
        }
        if interactor.env["COVERAGE_PRODUCE_JSON"] != nil {
            try interactor.run(
                """
                xcrun llvm-cov \
                export \
                -format text \
                \(lcovArgs.joined(separator: " ")) \
                @"\(llvmCoverageManifest)" \
                > >(tee '\(try interactor.env["COVERAGE_OUTPUT_FILE"].unwrap() + "coverage.json")') \
                2> >(tee '\(errorFile)' >&2)
                """
            )
            let errorLog = try interactor.read(errorFile)
            if !errorLog.isEmpty {
                // Error ourselves if lcov outputs warnings, such as if we misconfigure
                // something and the file path of one of the covered files doesn't exist
                throw TestRunnerError.warningsWhenExportingCoverageJson(try interactor.read(errorFile))
            }
        }
    }

    func getTmpDir() throws -> URL {
        guard let tmpDir = interactor.env["TEST_TMPDIR"].map({ $0.asPath }) else {
            throw TestRunnerError.missingTempDir
        }
        try interactor.mkdir(at: tmpDir)
        return tmpDir
    }

    func prepare(bundlePath: URL) throws {
        if bundlePath.pathExtension == "xctest" {
            try interactor.run("cp -cRL '\(bundlePath)' '\(interactor.tmpDir)'")
            // Need to modify permissions as Bazel will set all files to non-writable, and
            // Xcode's test runner requires the files to be writable.
            try interactor.run("chmod -R 777 '\(interactor.tmpDir)/\(bundlePath.name).xctest'")
        } else {
            try interactor.run("unzip -qq -d '\(interactor.tmpDir)' '\(bundlePath)'")
        }
    }

    func prepare(hostPath: URL?) throws {
        guard let hostPath = hostPath else {
            return
        }

        if hostPath.pathExtension == "app" {
            try interactor.run("cp -cRL '\(hostPath)' '\(interactor.tmpDir)'")
            // Need to modify permissions as Bazel will set all files to non-writable, and
            // Xcode's test runner requires the files to be writable.
            try interactor.run("chmod -R 777 '\(interactor.tmpDir)/\(hostPath.name).app'")
        } else {
            try interactor.run("unzip -qq -d '\(interactor.tmpDir)' '\(hostPath)'")
            try interactor.run("mv '\(interactor.tmpDir)'/Payload/*.app '\(interactor.tmpDir)'")
        }
    }


    func prepareEnv(testEnv: String?, hostPath: URL?) throws -> (xctestrunEnv: String, passthroughEnv: [String]) {
        // Add the test environment variables into the xctestrun file to propagate them to the test runner
        let testEnv: [(key: String, value: String)] = try {
            let inputEnv = try (testEnv ?? "").components(separatedBy: ",").filter { !$0.isEmpty }.map {
                let components = $0.components(separatedBy: "=")
                return try (key: components[safe: 0].unwrap(), value: components[safe: 1].unwrap())
            }
            let extraEnv = [
                (key: "TEST_SRCDIR", value: try interactor.env["TEST_SRCDIR"].unwrap()),
                (key: "TEST_UNDECLARED_OUTPUTS_DIR", value: try interactor.env["TEST_UNDECLARED_OUTPUTS_DIR"].unwrap())
            ]
            return inputEnv + extraEnv
        }()

        var xctestrunEnv: [String] = []
        var passthroughEnv: [String] = []

        for pair in testEnv {
            xctestrunEnv.append("<key>\(pair.key.xmlEscaped)</key>")
            xctestrunEnv.append("<string>\(pair.value.xmlEscaped)</string>")
            passthroughEnv.append("SIMCTL_CHILD_\(pair.key)='\(pair.value)'")
        }

        if let hostPath = hostPath {
            // If this is set in the case there is no test host, some tests hang indefinitely
            xctestrunEnv.append(
                "<key>XCInjectBundleInto</key><string>__TESTHOST__/\(hostPath.name.xmlEscaped).app/\(hostPath.name.xmlEscaped)</string>"
            )
        }

        return (xctestrunEnv: xctestrunEnv.joined(separator: "\n      "), passthroughEnv: passthroughEnv)
    }

    func prepareTestHostForUITests() throws -> String {
        // If ui testing is enabled we need to copy out the XCTRunner app, update its info.plist accordingly and finally
        // copy over the needed frameworks to enable ui testing

        let runnerAppName = "XCTRunner"
        let runnerApp = "\(runnerAppName).app"
        let runnerAppDestination = interactor.tmpDir + runnerApp

        let devDir = try interactor.getDeveloperDir()
        let librariesPath = devDir + "/Platforms/iPhoneSimulator.platform/Developer/Library"
        try interactor.run("cp -R \(librariesPath)/Xcode/Agents/XCTRunner.app \(runnerAppDestination)")
        try interactor.run("chmod -R 777 \(runnerAppDestination)")

        let infoPlistUrl = runnerAppDestination + "Info.plist"
        let infoPlist = try interactor.read(infoPlistUrl)
            .replacingOccurrences(of: "WRAPPEDPRODUCTNAME", with: runnerAppName)
            .replacingOccurrences(of: "WRAPPEDPRODUCTBUNDLEIDENTIFIER", with: "com.apple.test.\(runnerAppName)")

        try interactor.write(infoPlist, to: infoPlistUrl)

        let runnerAppFrameworksDestination = runnerAppDestination + "Frameworks"
        try interactor.mkdir(at: runnerAppFrameworksDestination)
        let frameworksToCopy = [
            "Frameworks/XCTest.framework",
            "PrivateFrameworks/XCTestCore.framework",
            "PrivateFrameworks/XCUIAutomation.framework",
            "PrivateFrameworks/XCTAutomationSupport.framework",
            "PrivateFrameworks/XCUnit.framework"
        ]
        for framework in frameworksToCopy {
            let origin = librariesPath + framework
            let destination = runnerAppFrameworksDestination.appendingPathComponent(origin.lastPathComponent)
            try interactor.copyItem(at: origin, to: destination)
        }

        return "__TESTROOT__/\(runnerApp)"
    }

    func prepareXctestrunHostPath(hostPath: URL?, testType: String) throws -> String {
        guard let hostPath = hostPath else {
            return "__PLATFORMS__/iPhoneSimulator.platform/Developer/Library/Xcode/Agents/xctest"
        }

        if testType == "XCUITEST" {
            return try prepareTestHostForUITests()
        } else {
            return "__TESTROOT__/\(hostPath.name).app"
        }
    }

    func prepareXcrunTargetAppPath(
        hostPath: URL?,
        testType: String
    ) -> String? {
        guard let hostPath = hostPath else {
            return nil
        }

        if testType == "XCUITEST" {
            return "__TESTROOT__/\(hostPath.name).app"
        } else {
            return nil
        }
    }

    func prepareSanitizerDyldEnv(bundlePath: URL) throws -> String? {
        let sanitizerRoot = interactor.tmpDir + "\(bundlePath.name).xctest/Frameworks"
        let libclangDlybs = try interactor
            .children(at: sanitizerRoot)
            .filter { $0.pathExtension == "dlyb" }
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix("libclang_rt") }
        return libclangDlybs.map { $0.path }.joined(separator: ":").nonEmptyOrNil
    }

    func prepareXctestrunTestFilters(testFilter: String?) -> (onlySection: String?, skipSection: String?) {
        guard let testFilter = testFilter else {
            return (onlySection: nil, skipSection: nil)
        }

        let testFilters = [interactor.env["TESTBRIDGE_TEST_ONLY"] ?? "", testFilter]
            .flatMap { $0.components(separatedBy: ",") }
            .filter { !$0.isEmpty }
        let (onlyFilters, skipFilters): (only: [String], skip: [String]) = testFilters.reduce(into: ([], [])) {
            if $1.hasPrefix("-") {
                $0.skip.append(String($1.trimmingPrefix("-")))
            } else {
                $0.only.append($1)
            }
        }
        let onlySection: String? = {
            guard !skipFilters.isEmpty else {
                return nil
            }

            let xml = skipFilters.reduce(into: "") { $0 += "      <string>\($1)</string>\n" }
            return "    <key>SkipTestIdentifiers</key>\n    <array>\n\(xml)    </array>"
        }()
        let skipSection: String? = {
            guard !onlyFilters.isEmpty else {
                return nil
            }

            let xml = onlyFilters.reduce(into: "") { $0 += "      <string>\($1)</string>\n" }
            return "    <key>OnlyTestIdentifiers</key>\n    <array>\n\(xml)    </array>"
        }()
        return (onlySection: onlySection, skipSection: skipSection)
    }

    func prepareXctestrunLibraries(sanitizerDyldEnv: String?) -> String {
        return [
            "__PLATFORMS__/iPhoneSimulator.platform/Developer/usr/lib/libXCTestBundleInject.dylib",
            sanitizerDyldEnv
        ]
            .compactMap { $0 }
            .joined(separator: ":")
    }

    func prepareSimulator(input: Input) throws -> String {
        let args = [
            "'\(input.osVersion)'",
            "'\(input.deviceType)'",
            input.simulatorName.map { "--name '\($0)'" },
            input.reuseSimulator ? "--reuse-simulator" : "--no-reuse-simulator"
        ]
            .compactMap { $0 }
            .joined(separator: " ")
        let simulatorId = try interactor.run("'\(input.simulatorCreator)' \(args)")
        return simulatorId
    }

    func needsIntelSimulatorHack(bundlePath: URL) throws -> Bool {
        let testFile = try interactor.run("file '\(interactor.tmpDir)/\(bundlePath.name).xctest/\(bundlePath.name)'")
        return try interactor.run("arch") == "arm64" && !testFile.contains("arm64")
    }

    func shouldUseXcodebuild(
        hostPath: URL?,
        random: Bool,
        createXcresultBundle: Bool,
        xctestrunSkipTestSection: String?,
        xctestrunOnlyTestSection: String?,
        xcodebuildArgs: [String]
    ) -> Bool {
        if hostPath != nil {
            interactor.print(.note, "using 'xcodebuild' because test host was provided")
            return true
        }

        if random {
            interactor.print(.note, "using 'xcodebuild' because random test order was requested")
            return true
        }

        if createXcresultBundle {
            interactor.print(.note, "using 'xcodebuild' because XCResult bundle was requested")
            return true
        }

        if xctestrunSkipTestSection != nil || xctestrunOnlyTestSection != nil {
            interactor.print(.note, "using 'xcodebuild' because test filter was provided")
            return true
        }

        if !xcodebuildArgs.isEmpty {
            interactor.print(.note, "using 'xcodebuild' because '--xcodebuildArgs' was provided")
            return true
        }

        return false
    }

    func makeXcodebuildArgs(
        input: Input,
        simulatorId: String,
        xctestrunFile: URL
    ) throws -> String {
        var args = [
            "-destination id=\(simulatorId)",
            "-destination-timeout 15",
            "-xctestrun '\(xctestrunFile)'"
        ]
        let resultBundlePath = try interactor.env["TEST_UNDECLARED_OUTPUTS_DIR"].unwrap() + "tests.xcresult"
        // TEST_UNDECLARED_OUTPUTS_DIR isn't cleaned up with multiple retries of flaky tests
        try interactor.run("rm -rf '\(resultBundlePath)'")
        if input.createXcresultBundle {
            args.append("-resultBundlePath '\(resultBundlePath)'")
        }
        args += input.xcodebuildArgs
        return args.joined(separator: " ")
    }

    func prepareXctestrunFile(
        replacements: [String: String],
        templatePath: URL
    ) throws -> URL {
        let xctestrunFile = interactor.tmpDir + "tests.xctestrun"
        var xctestrunFileContent = try interactor.read(templatePath)
        for replacement in replacements {
            xctestrunFileContent = xctestrunFileContent.replacingOccurrences(of: replacement.key, with: replacement.value)
        }
        try interactor.write(xctestrunFileContent, to: xctestrunFile)
        return xctestrunFile
    }

    func prepareXctestBinary(
        platformDeveloperDir: URL,
        intelSimulatorHack: Bool
    ) throws -> URL {
        let vanillaBinary = platformDeveloperDir + "Library/Xcode/Agents/xctest"
        let xctestBinary: URL
        if intelSimulatorHack {
            xctestBinary = interactor.tmpDir + "xctest_intel_bin"
            try interactor.run("lipo -thin x86_64 -output \(xctestBinary) \(vanillaBinary)")
        } else {
            xctestBinary = vanillaBinary
        }
        return xctestBinary
    }
}

private extension String {
    // Prefer to use nil to represent a missing argument instead of an empty string
    var cleanedUpArgument: String? {
        return self.nonEmptyOrNil
    }
}

private extension Array where Element == String {
    // Prefer to use an empty array to represent no elements passed as arguments instead of an optional array
    var cleanedUpArgument: [Element] {
        self.compactMap { $0.nonEmptyOrNil }
    }
}
