import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var statusItem: NSStatusItem?
  var statusMenuItem: NSMenuItem?
  var statusBarChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    setupStatusBar()
    setupMethodChannel()
  }

  func setupStatusBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.isVisible = true
    if let button = statusItem?.button {
      let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "计划清单")
      image?.isTemplate = true
      button.image = image
      button.imagePosition = .imageLeft
      button.title = " 空闲"
    }

    let menu = NSMenu()
    let titleItem = NSMenuItem(title: "计划清单 • 空闲", action: nil, keyEquivalent: "")
    titleItem.isEnabled = false
    menu.addItem(titleItem)
    statusMenuItem = titleItem

    menu.addItem(NSMenuItem.separator())

    let openItem = NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow), keyEquivalent: "o")
    openItem.target = self
    menu.addItem(openItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(title: "退出应用", action: #selector(quitApp), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem?.menu = menu
  }

  func setupMethodChannel() {
    guard let window = mainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController else {
      DispatchQueue.main.async { [weak self] in
        self?.setupMethodChannel()
      }
      return
    }
    statusBarChannel = FlutterMethodChannel(name: "com.antigravity.schedule/status_bar", binaryMessenger: controller.engine.binaryMessenger)
    statusBarChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "updateStatus" {
        if let args = call.arguments as? [String: Any] {
          let statusText = args["statusText"] as? String ?? "空闲"
          let isRunning = args["isRunning"] as? Bool ?? false
          self.updateStatus(statusText: statusText, isRunning: isRunning)
        }
        result(nil)
      } else if call.method == "showMainWindow" {
        self.showMainWindow()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func updateStatus(statusText: String, isRunning: Bool) {
    DispatchQueue.main.async {
      if let button = self.statusItem?.button {
        button.title = " \(statusText)"
        if isRunning {
          button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "进行中")
        } else {
          button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "空闲")
        }
        let symbolName = isRunning ? "timer" : "checklist"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: isRunning ? "进行中" : "空闲")
        image?.isTemplate = true
        button.image = image
      }
      self.statusMenuItem?.title = "计划清单 • \(statusText)"
    }
  }

  @objc func showMainWindow() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = mainFlutterWindow {
      window.makeKeyAndOrderFront(nil)
      window.orderFrontRegardless()
    }
  }

  @objc func quitApp() {
    NSApp.terminate(nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      showMainWindow()
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
