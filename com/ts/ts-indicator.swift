// ts-indicator — minimal gray menu-bar dot shown while the tailnet is up.
// Spawned by `ts up` / `ts status`; polls `tailscale status --json` every
// 5s and exits as soon as BackendState != Running, so the dot can never
// claim a VPN state the backend doesn't have. No menu, no clicks, no deps.
// Build: swiftc -O -o ~/bin/ts-indicator ts-indicator.swift
import AppKit

func backendIsRunning() -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = ["tailscale", "status", "--peers=false", "--json"]
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = (env["PATH"] ?? "") + ":/opt/homebrew/bin:/usr/local/bin"
    p.environment = env
    let out = Pipe()
    p.standardOutput = out
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return false }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard p.terminationStatus == 0,
          let text = String(data: data, encoding: .utf8) else { return false }
    return text.range(of: #""BackendState":\s*"Running""#,
                      options: .regularExpression) != nil
}

guard backendIsRunning() else { exit(0) }   // never show a dot we can't back up

let app = NSApplication.shared
app.setActivationPolicy(.accessory)         // menu-bar only; no Dock icon

let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.button?.attributedTitle = NSAttributedString(
    string: "\u{25CF}",                     // ●
    attributes: [.foregroundColor: NSColor.secondaryLabelColor])

Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
    if !backendIsRunning() { app.terminate(nil) }
}
app.run()
