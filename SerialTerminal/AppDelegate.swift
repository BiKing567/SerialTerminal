import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var windows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        newWindow(nil)
    }

    @objc func newWindow(_ sender: Any?) {
        let contentView = ContentView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.center()
        window.title = "Serial Terminal"
        window.minSize = NSSize(width: 700, height: 500)
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }

    @objc func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            windows.removeAll { $0 === window }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 应用菜单
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 SerialTerminal", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 SerialTerminal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // 文件菜单（新建窗口）
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "文件")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "新建窗口", action: #selector(newWindow(_:)), keyEquivalent: "n")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        // 编辑菜单（保证 Cmd+C/V 等快捷键可用）
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }
}
