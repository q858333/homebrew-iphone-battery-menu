import AppKit
import Foundation

enum DevicePlatform: String {
    case iPhone
    case android = "Android"
}

struct Device: Equatable {
    let udid: String
    let name: String
    let platform: DevicePlatform

    var identity: String {
        "\(platform.rawValue):\(udid)"
    }

    var displayName: String {
        "\(platform.rawValue) \(name)"
    }
}

struct BatteryStatus {
    let level: Int
    let isCharging: Bool?
}

struct AndroidBatteryParser {
    static func parse(_ dump: String) throws -> BatteryStatus {
        var level: Int?
        var status: Int?

        for line in dump.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2 else { continue }

            switch parts[0] {
            case "level":
                level = Int(parts[1])
            case "status":
                status = Int(parts[1])
            default:
                break
            }
        }

        guard let level else {
            throw NSError(
                domain: "iPhoneBatteryMenu.AndroidBattery",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Android battery level not found."]
            )
        }

        return BatteryStatus(level: level, isCharging: status.map { $0 == 2 || $0 == 5 })
    }
}

final class CommandOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var output = ""
    private var error = ""

    func append(_ text: String, isError: Bool) {
        lock.lock()
        if isError {
            error += text
        } else {
            output += text
        }
        lock.unlock()
    }

    var failureMessage: String {
        lock.lock()
        let message = error.isEmpty ? output : error
        lock.unlock()
        return message
    }
}

final class CommandRunner: @unchecked Sendable {
    let batteryDomain = "com.apple.mobile.battery"

    var hasDependencies: Bool {
        Self.findExecutable("idevice_id") != nil
            && Self.findExecutable("ideviceinfo") != nil
            && Self.findExecutable("adb") != nil
    }

    private static func findExecutable(_ name: String) -> String? {
        var paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)"
        ]

        if let home = ProcessInfo.processInfo.environment["HOME"] {
            paths.append("\(home)/Library/Android/sdk/platform-tools/\(name)")
        }

        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func requiredExecutable(_ name: String) throws -> String {
        if let path = findExecutable(name) {
            return path
        }

        throw NSError(
            domain: "iPhoneBatteryMenu.Dependency",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "\(name) is not installed. Install Homebrew libimobiledevice and android-platform-tools."]
        )
    }

    func installDependencies(progress: @escaping @Sendable (String) -> Void) throws {
        guard !hasDependencies else { return }

        guard let brewPath = Self.findExecutable("brew") else {
            throw NSError(
                domain: "iPhoneBatteryMenu.Dependency",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Homebrew is not installed. Install Homebrew first, then relaunch this app."]
            )
        }

        progress("Running brew install libimobiledevice android-platform-tools...")
        try runWithProgress(brewPath, ["install", "libimobiledevice", "android-platform-tools"], progress: progress)

        guard hasDependencies else {
            throw NSError(
                domain: "iPhoneBatteryMenu.Dependency",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Device tools installed, but idevice_id, ideviceinfo, or adb was not found."]
            )
        }
    }

    private func runWithProgress(_ executable: String, _ arguments: [String], progress: @escaping @Sendable (String) -> Void) throws {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let outputBuffer = CommandOutputBuffer()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let capture: @Sendable (Data, Bool) -> Void = { data, isError in
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            outputBuffer.append(text, isError: isError)

            if let line = lines.last {
                progress(line)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            capture(handle.availableData, false)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            capture(handle.availableData, true)
        }

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        capture(outputPipe.fileHandleForReading.readDataToEndOfFile(), false)
        capture(errorPipe.fileHandleForReading.readDataToEndOfFile(), true)

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "iPhoneBatteryMenu.Command",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: outputBuffer.failureMessage]
            )
        }
    }

    func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "iPhoneBatteryMenu.Command",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: error.isEmpty ? output : error]
            )
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func listDevices() throws -> [Device] {
        let iPhones = (try? listIPhones()) ?? []
        let androids = (try? listAndroidDevices()) ?? []
        return iPhones + androids
    }

    private func listIPhones() throws -> [Device] {
        let output = try run(Self.requiredExecutable("idevice_id"), ["-l"])
        let udids = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return udids.map { udid in
            Device(udid: udid, name: iPhoneName(udid: udid), platform: .iPhone)
        }
    }

    private func listAndroidDevices() throws -> [Device] {
        let output = try run(Self.requiredExecutable("adb"), ["devices"])
        let serials = output
            .split(whereSeparator: \.isNewline)
            .dropFirst()
            .compactMap { line -> String? in
                let parts = line.split(whereSeparator: \.isWhitespace)
                guard parts.count >= 2, parts[1] == "device" else { return nil }
                return String(parts[0])
            }

        return serials.map { serial in
            Device(udid: serial, name: androidName(serial: serial), platform: .android)
        }
    }

    func batteryStatus(for device: Device) throws -> BatteryStatus {
        switch device.platform {
        case .iPhone:
            return try iPhoneBatteryStatus(udid: device.udid)
        case .android:
            return try androidBatteryStatus(serial: device.udid)
        }
    }

    private func iPhoneBatteryStatus(udid: String) throws -> BatteryStatus {
        let levelText = try iPhoneValue(udid: udid, key: "BatteryCurrentCapacity")
        let chargingText = try? iPhoneValue(udid: udid, key: "BatteryIsCharging")
        let level = Int(levelText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
        let isCharging = chargingText.map { $0 == "true" || $0 == "1" }
        return BatteryStatus(level: level, isCharging: isCharging)
    }

    private func androidBatteryStatus(serial: String) throws -> BatteryStatus {
        let output = try run(Self.requiredExecutable("adb"), ["-s", serial, "shell", "dumpsys", "battery"])
        return try AndroidBatteryParser.parse(output)
    }

    private func iPhoneValue(udid: String, key: String) throws -> String {
        try run(Self.requiredExecutable("ideviceinfo"), ["-u", udid, "-q", batteryDomain, "-k", key])
    }

    private func iPhoneName(udid: String) -> String {
        (try? run(Self.requiredExecutable("ideviceinfo"), ["-u", udid, "-k", "DeviceName"])) ?? udid
    }

    private func androidName(serial: String) -> String {
        let model = try? run(Self.requiredExecutable("adb"), ["-s", serial, "shell", "getprop", "ro.product.model"])
        return model?.isEmpty == false ? model! : serial
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runner = CommandRunner()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var menu = NSMenu()
    private var devices: [Device] = []
    private var selectedDevice: Device?
    private var timer: Timer?
    private var lastNotificationLevel: Int?
    private var notifyAtLevel: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: "notifyAtLevel")
            return saved == 0 ? 78 : saved
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 1), 100), forKey: "notifyAtLevel")
            lastNotificationLevel = nil
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem.button?.title = "ChargePeek --%"
        rebuildMenu(message: "Scanning...")
        refreshAfterDependencyCheck()

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBattery()
            }
        }
    }

    private func refreshAfterDependencyCheck() {
        guard runner.hasDependencies else {
            installDependencies()
            return
        }

        refreshDevices()
        refreshBattery()
    }

    private func installDependencies() {
        statusItem.button?.title = "Installing"
        rebuildMenu(message: "Installing device tools...")

        let runner = self.runner
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try runner.installDependencies { message in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.statusItem.button?.title = "Installing..."
                        self.rebuildMenu(message: self.clean("Installing: \(message)"))
                    }
                }
            }

            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .success:
                    self.statusItem.button?.title = "ChargePeek --%"
                    self.refreshDevices()
                    self.refreshBattery()
                case .failure(let error):
                    self.statusItem.button?.title = "Setup failed"
                    self.rebuildMenu(message: self.clean(error.localizedDescription))
                }
            }
        }
    }

    private func refreshDevices() {
        do {
            devices = try runner.listDevices()
            if selectedDevice == nil || !devices.contains(where: { $0.identity == selectedDevice?.identity }) {
                selectedDevice = devices.first
            }
            rebuildMenu()
        } catch {
            statusItem.button?.title = "Device ?"
            rebuildMenu(message: "Device scan failed: \(clean(error.localizedDescription))")
        }
    }

    @objc private func refreshBattery() {
        if selectedDevice == nil {
            refreshDevices()
        }

        guard let device = selectedDevice else {
            statusItem.button?.title = "No Device"
            rebuildMenu(message: "No iPhone or Android device found")
            return
        }

        do {
            let status = try runner.batteryStatus(for: device)
            let chargingMark = status.isCharging == true ? " ⚡" : ""
            statusItem.button?.title = "\(status.level)%\(chargingMark)"
            rebuildMenu(message: "\(device.displayName): \(status.level)%\(chargingMark) · Alert: \(notifyAtLevel)%")

            if status.level >= notifyAtLevel && lastNotificationLevel != status.level {
                lastNotificationLevel = status.level
                notify(title: "ChargePeek", body: "\(device.displayName) is at \(status.level)%")
            }
        } catch {
            statusItem.button?.title = "Read failed"
            rebuildMenu(message: clean(error.localizedDescription))
        }
    }

    private func rebuildMenu(message: String? = nil) {
        menu = NSMenu()

        if let message {
            let item = NSMenuItem(title: message, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        }

        if devices.isEmpty {
            let item = NSMenuItem(title: "No devices", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for device in devices {
                let item = NSMenuItem(title: "\(device.displayName) (\(device.udid))", action: #selector(selectDevice(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.identity
                item.state = device.identity == selectedDevice?.identity ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Alert Level: \(notifyAtLevel)%", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Set Alert Level...", action: #selector(setAlertLevel), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Battery", action: #selector(refreshBattery), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Refresh Devices", action: #selector(refreshDevicesAction), keyEquivalent: "d"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let identity = sender.representedObject as? String else { return }
        selectedDevice = devices.first { $0.identity == identity }
        lastNotificationLevel = nil
        refreshBattery()
    }

    @objc private func refreshDevicesAction() {
        refreshDevices()
        refreshBattery()
    }

    @objc private func setAlertLevel() {
        let alert = NSAlert()
        alert.messageText = "Set battery alert level"
        alert.informativeText = "Enter a percentage from 1 to 100."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        input.stringValue = String(notifyAtLevel)
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn,
           let value = Int(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
           (1...100).contains(value) {
            notifyAtLevel = value
            refreshBattery()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func notify(title: String, body: String) {
        let script = "display notification \(quotedAppleScript(body)) with title \(quotedAppleScript(title))"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private func quotedAppleScript(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@main
struct ChargePeekApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
