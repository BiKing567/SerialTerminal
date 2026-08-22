import Foundation
import AppKit
import Combine

final class Updater: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case checking
        case available(version: String)
        case downloading
        case installing
        case upToDate
        case failed(String)
    }

    @Published var state: State = .idle
    @Published var progress: Double = 0
    @Published var showHUD: Bool = false

    private let repo = "BiKing567/SerialTerminal"
    private var session: URLSession!
    private var downloadURL: URL?

    override private init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func dismiss() {
        showHUD = false
        state = .idle
    }

    // MARK: - 检查更新
    func checkForUpdates(auto: Bool) {
        DispatchQueue.main.async {
            self.state = .checking
            if !auto { self.showHUD = true }
        }
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("SerialTerminal-Updater", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard let data = data, err == nil,
                      let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                    self.state = auto ? .idle : .failed("网络请求失败")
                    if auto { self.showHUD = false }
                    return
                }
                guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = obj["tag_name"] as? String else {
                    self.state = auto ? .idle : .failed("响应解析失败")
                    return
                }
                let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                if self.isNewer(remote, self.currentVersion),
                   let assets = obj["assets"] as? [[String: Any]],
                   let asset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") ?? false }),
                   let dl = asset["browser_download_url"] as? String,
                   let dlURL = URL(string: dl) {
                    self.downloadURL = dlURL
                    self.state = .available(version: remote)
                    self.showHUD = true
                } else {
                    self.state = auto ? .idle : .upToDate
                    if !auto { self.showHUD = true }   // 手动检查时显示"已是最新"
                }
            }
        }.resume()
    }

    // MARK: - 下载
    func startUpdate() {
        guard let url = downloadURL else { return }
        state = .downloading
        progress = 0
        session.downloadTask(with: url).resume()
    }

    func cancelUpdate() {
        session.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
        DispatchQueue.main.async {
            self.state = .idle
            self.showHUD = false
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        DispatchQueue.main.async {
            self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("serialterminal_update.dmg")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            DispatchQueue.main.async { self.mountAndInstall(dmg: dest) }
        } catch {
            DispatchQueue.main.async { self.state = .failed("保存下载文件失败") }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        let nsError = error as NSError
        // 用户主动取消（URLSession 取消产生 URLError.cancelled / -999）
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if nsError.code == NSUserCancelledError { return }
        DispatchQueue.main.async { self.state = .failed("下载失败: \(error.localizedDescription)") }
    }

    // MARK: - 挂载 + 安装
    private func mountAndInstall(dmg: URL) {
        state = .installing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let attach = Process()
            attach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            attach.arguments = ["attach", dmg.path, "-nobrowse", "-quiet"]
            do {
                try attach.run()
            } catch {
                DispatchQueue.main.async { self.state = .failed("无法执行 hdiutil") }
                return
            }
            let sema = DispatchSemaphore(value: 0)
            attach.terminationHandler = { _ in sema.signal() }
            if sema.wait(timeout: .now() + 60) == .timedOut {
                attach.terminate()
                DispatchQueue.main.async { self.state = .failed("挂载更新镜像超时") }
                return
            }

            var volumeURL: URL?
            let volumes = (try? FileManager.default.contentsOfDirectory(atPath: "/Volumes")) ?? []
            for v in volumes {
                let candidate = URL(fileURLWithPath: "/Volumes/\(v)")
                if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("SerialTerminal.app").path) {
                    volumeURL = candidate
                    break
                }
            }
            DispatchQueue.main.async {
                guard let volume = volumeURL else {
                    self.state = .failed("挂载更新镜像失败")
                    return
                }
                self.runInstallScript(volume: volume)
            }
        }
    }

    private func runInstallScript(volume: URL) {
        let currentPath = Bundle.main.bundlePath
        let target = currentPath.contains("/Volumes/") ? "/Applications/SerialTerminal.app" : currentPath
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/bash
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        sleep 0.5
        if rm -rf "\(target)" && ditto "\(volume.path)/SerialTerminal.app" "\(target)"; then
          hdiutil detach "\(volume.path)" -quiet 2>/dev/null
          open "\(target)"
        else
          open "\(volume.path)"
        fi
        """
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("serialterminal_update.sh")
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [scriptURL.path]
        do {
            try p.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed("无法启动安装脚本")
            NSWorkspace.shared.open(volume)
        }
    }

    private func isNewer(_ remote: String, _ current: String) -> Bool {
        let r = remote.split(separator: ".").map { Int($0) ?? 0 }
        let c = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }
}
