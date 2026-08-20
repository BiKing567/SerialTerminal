import SwiftUI
import Combine
import UniformTypeIdentifiers

struct MessageItem: Identifiable {
    let id = UUID()
    let data: Data
    let timestamp: Date
    let isIncoming: Bool
    let displayString: String
}

class TerminalViewModel: ObservableObject {
    @Published var selectedPort: SerialPortInfo?
    @Published var isConnected: Bool = false
    @Published var messages: [MessageItem] = []
    @Published var sendText: String = ""
    @Published var autoScroll: Bool = true
    @Published var showTimestamps: Bool = true
    @Published var displayMode: DisplayMode = .ascii
    @Published var isLogging: Bool = false
    @Published var logFilePath: String = ""
    @Published var showHexInput: Bool = false
    @Published var hexInputText: String = ""

    @Published var config: SerialConfig = SerialConfig()

    // Line ending
    enum LineEnding: String, CaseIterable, Identifiable {
        case none, cr, lf, crlf
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "无"
            case .cr: return "CR (\\r)"
            case .lf: return "LF (\\n)"
            case .crlf: return "CRLF (\\r\\n)"
            }
        }
    }
    @Published var lineEnding: LineEnding = .lf

    // Encoding
    enum DisplayEncoding: String, CaseIterable, Identifiable {
        case auto, utf8, gbk, latin1
        var id: String { rawValue }
        var label: String {
            switch self {
            case .auto: return "自动"
            case .utf8: return "UTF-8"
            case .gbk: return "GB18030/GBK"
            case .latin1: return "Latin-1"
            }
        }
    }
    @Published var displayEncoding: DisplayEncoding = .auto

    // Auto send
    @Published var autoSendEnabled: Bool = false {
        didSet {
            if autoSendEnabled { startAutoSend() } else { stopAutoSend() }
        }
    }
    @Published var autoSendInterval: Double = 1.0
    private var autoSendTimer: Timer?

    // Send history
    @Published var sendHistory: [String] = []

    // RX/TX counters (mirrored from serialManager)
    @Published var rxBytes: UInt64 = 0
    @Published var txBytes: UInt64 = 0

    // DTR/RTS
    @Published var dtrEnabled: Bool = true
    @Published var rtsEnabled: Bool = true

    enum DisplayMode: String, CaseIterable {
        case ascii = "ASCII"
        case hex = "HEX"
        case both = "ASCII + HEX"
    }

    let serialManager = SerialPortManager()
    private var logFileHandle: FileHandle?
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    private var cancellables = Set<AnyCancellable>()

    init() {
        serialManager.delegate = self
        serialManager.onError = { [weak self] error in
            self?.messages.append(MessageItem(
                data: Data(),
                timestamp: Date(),
                isIncoming: true,
                displayString: "[ERROR] \(error)"
            ))
        }

        serialManager.onDisconnectedMessage = { [weak self] message in
            self?.messages.append(MessageItem(
                data: Data(),
                timestamp: Date(),
                isIncoming: true,
                displayString: message
            ))
        }

        serialManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Mirror rxBytes/txBytes from serialManager
        serialManager.$rxBytes
            .receive(on: DispatchQueue.main)
            .assign(to: &$rxBytes)
        serialManager.$txBytes
            .receive(on: DispatchQueue.main)
            .assign(to: &$txBytes)

        // Load send history
        sendHistory = UserDefaults.standard.stringArray(forKey: "sendHistory") ?? []
    }

    func refreshPorts() {
        serialManager.refreshPorts()
    }

    func toggleConnection() {
        if isConnected {
            disconnect()
        } else {
            connect()
        }
    }

    func connect() {
        guard let port = selectedPort else { return }
        serialManager.config = config
        serialManager.connect(to: port)
    }

    func disconnect() {
        stopAutoSend()
        autoSendEnabled = false
        serialManager.disconnect()
    }

    func send() {
        guard isConnected else { return }
        if showHexInput {
            sendHex(hexInputText)
            switch lineEnding {
            case .none: break
            case .cr: serialManager.send(Data([0x0D]))
            case .lf: serialManager.send(Data([0x0A]))
            case .crlf: serialManager.send(Data([0x0D, 0x0A]))
            }
            addToHistory(hexInputText)
        } else {
            var text = sendText
            switch lineEnding {
            case .none: break
            case .cr: text += "\r"
            case .lf: text += "\n"
            case .crlf: text += "\r\n"
            }
            serialManager.send(text)
            addToHistory(sendText)
        }
    }

    func sendHex(_ hexString: String) {
        var cleaned = hexString.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .uppercased()
        if !cleaned.isEmpty && cleaned.count % 2 != 0 {
            cleaned = "0" + cleaned
        }

        var data = Data()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
            if nextIndex > index {
                let byteStr = String(cleaned[index..<nextIndex])
                if let byte = UInt8(byteStr, radix: 16) {
                    data.append(byte)
                }
            }
            index = nextIndex
        }

        if !data.isEmpty {
            serialManager.send(data)
            addMessage(data, timestamp: Date(), isIncoming: false)
        }
    }

    func clearMessages() {
        messages.removeAll()
    }

    func toggleLogging() {
        if isLogging {
            stopLogging()
        } else {
            startLogging()
        }
    }

    func startLogging() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "serial_log_\(Date().ISO8601Format()).txt"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            logFileHandle = try? FileHandle(forWritingTo: url)
            logFilePath = url.path
            isLogging = true
        }
    }

    func stopLogging() {
        try? logFileHandle?.close()
        logFileHandle = nil
        isLogging = false
    }

    private func handleReceivedData(_ data: Data, timestamp: Date) {
        addMessage(data, timestamp: timestamp, isIncoming: true)
    }

    private func addMessage(_ data: Data, timestamp: Date, isIncoming: Bool) {
        let displayString = formatMessage(data, timestamp: timestamp, isIncoming: isIncoming)
        let item = MessageItem(data: data, timestamp: timestamp, isIncoming: isIncoming, displayString: displayString)

        DispatchQueue.main.async {
            self.messages.append(item)
            if self.messages.count > 5000 {
                self.messages.removeFirst(self.messages.count - 5000)
            }
        }

        if isLogging, let handle = logFileHandle {
            let logEntry = "\(dateFormatter.string(from: timestamp)) \(isIncoming ? "RX" : "TX"): \(displayString)\n"
            if let logData = logEntry.data(using: .utf8) {
                try? handle.write(contentsOf: logData)
            }
        }
    }

    private func formatMessage(_ data: Data, timestamp: Date, isIncoming: Bool) -> String {
        let dir = isIncoming ? "RX" : "TX"
        var result = ""

        if showTimestamps {
            result += "[\(dateFormatter.string(from: timestamp))] "
        }
        result += "[\(dir)] "

        switch displayMode {
        case .ascii:
            result += formatAscii(data)
        case .hex:
            result += formatHex(data)
        case .both:
            result += formatAscii(data) + " | " + formatHex(data)
        }

        return result
    }

    private func formatAscii(_ data: Data) -> String {
        let gbk = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        let decoded: String
        switch displayEncoding {
        case .auto:
            if let s = String(data: data, encoding: .utf8) { decoded = s }
            else if let s = String(data: data, encoding: gbk) { decoded = s }
            else { decoded = String(data: data, encoding: .isoLatin1) ?? "" }
        case .utf8:
            decoded = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) ?? ""
        case .gbk:
            decoded = String(data: data, encoding: gbk)
                ?? String(data: data, encoding: .isoLatin1) ?? ""
        case .latin1:
            decoded = String(data: data, encoding: .isoLatin1) ?? ""
        }
        return sanitizeForDisplay(decoded)
    }

    private func sanitizeForDisplay(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for scalar in string.unicodeScalars {
            let value = scalar.value
            if value == 13 || value == 10 {
                result.append("\u{21B5}")
            } else if value < 32 {
                result.append(".")
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private func formatHex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    // MARK: - Auto Send

    func startAutoSend() {
        stopAutoSend()
        guard isConnected else { return }
        let interval = max(0.1, autoSendInterval)
        autoSendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.send()
        }
    }

    func stopAutoSend() {
        autoSendTimer?.invalidate()
        autoSendTimer = nil
    }

    // MARK: - Send History

    private func addToHistory(_ text: String) {
        guard !text.isEmpty else { return }
        sendHistory.removeAll { $0 == text }
        sendHistory.insert(text, at: 0)
        if sendHistory.count > 50 { sendHistory.removeLast(sendHistory.count - 50) }
        UserDefaults.standard.set(sendHistory, forKey: "sendHistory")
    }

    // MARK: - RX/TX Counters

    func resetCounters() {
        rxBytes = 0
        txBytes = 0
        serialManager.rxBytes = 0
        serialManager.txBytes = 0
    }

    // MARK: - DTR/RTS

    func setDTR(_ on: Bool) {
        dtrEnabled = on
        serialManager.setDTR(on)
    }

    func setRTS(_ on: Bool) {
        rtsEnabled = on
        serialManager.setRTS(on)
    }

    // MARK: - Export

    func exportMessages() {
        let panel = NSSavePanel()
        panel.title = "导出串口会话"
        panel.nameFieldStringValue = "SerialTerminal-export.txt"
        panel.allowedContentTypes = [.plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let lines = self.messages.map { $0.displayString }
            let content = lines.joined(separator: "\n") + "\n"
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

extension TerminalViewModel: SerialPortManagerDelegate {
    func serialPortDidReceive(data: Data, timestamp: Date) {
        handleReceivedData(data, timestamp: timestamp)
    }

    func serialPortDidConnect() {
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }

    func serialPortDidDisconnect() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.stopAutoSend()
            self.autoSendEnabled = false
        }
    }

    func serialPortDidEncounterError(_ error: String) {
        DispatchQueue.main.async {
            self.messages.append(MessageItem(
                data: Data(),
                timestamp: Date(),
                isIncoming: true,
                displayString: "[ERROR] \(error)"
            ))
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TerminalViewModel()
    @State private var showSettings: Bool = false
    @State private var autoRefreshTimer: Timer?
    @AppStorage("terminalFontSize") private var fontSize: Double = 13
    @State private var eventMonitor: Any? = nil
    @State private var baseScale: Double = 13
    
    var body: some View {
        VStack(spacing: 0) {
            connectionToolbar
            Divider()
            terminalView
            Divider()
            sendPanel
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            viewModel.refreshPorts()
            baseScale = fontSize
            autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                if !viewModel.isConnected {
                    viewModel.refreshPorts()
                }
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
                if event.modifierFlags.contains(.control) {
                    let step: Double = event.scrollingDeltaY > 0 ? 1 : -1
                    var newSize = fontSize + step
                    newSize = max(8, min(72, newSize))
                    if newSize != fontSize {
                        fontSize = newSize
                        baseScale = newSize
                    }
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            autoRefreshTimer?.invalidate()
            autoRefreshTimer = nil
            viewModel.disconnect()
        }
    }

    private var connectionToolbar: some View {
        HStack(spacing: 12) {
            Picker("串口", selection: $viewModel.selectedPort) {
                Text("选择串口").tag(nil as SerialPortInfo?)
                ForEach(viewModel.serialManager.availablePorts) { port in
                    Text(port.name).tag(port as SerialPortInfo?)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 140)
            .disabled(viewModel.isConnected)

            Picker("波特率", selection: $viewModel.config.baudRate) {
                ForEach(SerialConfig.baudRates, id: \.self) { rate in
                    Text("\(rate)").tag(rate)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 120)
            .disabled(viewModel.isConnected)

            Button(action: { viewModel.refreshPorts() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isConnected)
            .help("刷新串口列表")

            Button(action: viewModel.toggleConnection) {
                HStack {
                    Image(systemName: viewModel.isConnected ? "stop.fill" : "play.fill")
                    Text(viewModel.isConnected ? "断开" : "连接")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isConnected ? .red : .green)

            Toggle("DTR", isOn: Binding(
                get: { viewModel.dtrEnabled },
                set: { viewModel.setDTR($0) }
            ))
            .disabled(!viewModel.isConnected)
            .toggleStyle(.checkbox)
            Toggle("RTS", isOn: Binding(
                get: { viewModel.rtsEnabled },
                set: { viewModel.setRTS($0) }
            ))
            .disabled(!viewModel.isConnected)
            .toggleStyle(.checkbox)

            Spacer()

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    private var terminalView: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $viewModel.displayMode) {
                    ForEach(TerminalViewModel.DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Text("RX: \(viewModel.rxBytes) B")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("TX: \(viewModel.txBytes) B")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Button("清零") { viewModel.resetCounters() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))

                Spacer()

                Toggle("时间戳", isOn: $viewModel.showTimestamps)
                    .toggleStyle(.checkbox)

                Toggle("自动滚动", isOn: $viewModel.autoScroll)
                    .toggleStyle(.checkbox)

                Button(action: viewModel.clearMessages) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .help("清空显示")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.messages) { message in
                            Text(message.displayString)
                                .font(.system(size: fontSize, design: .monospaced))
                                .foregroundColor(message.isIncoming ? .primary : .blue)
                                .textSelection(.enabled)
                                .id(message.id)
                        }
                    }
                    .padding(8)
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            let newSize = baseScale * scale
                            fontSize = max(8, min(72, newSize))
                        }
                        .onEnded { scale in
                            baseScale = fontSize
                        }
                )
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: viewModel.messages.count) { _ in
                    if viewModel.autoScroll, let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var sendPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("", selection: $viewModel.showHexInput) {
                    Text("文本").tag(false)
                    Text("HEX").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)

                if viewModel.showHexInput {
                    TextField("输入HEX (如: 01 02 03)", text: $viewModel.hexInputText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .onSubmit {
                            viewModel.send()
                        }
                } else {
                    TextField("输入发送内容...", text: $viewModel.sendText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            viewModel.send()
                        }
                }

                Button(action: viewModel.send) {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.showHexInput ? viewModel.hexInputText.isEmpty : viewModel.sendText.isEmpty)

                Menu {
                    ForEach(TerminalViewModel.LineEnding.allCases) { ending in
                        Button {
                            viewModel.lineEnding = ending
                        } label: {
                            if viewModel.lineEnding == ending {
                                Label(ending.label, systemImage: "checkmark")
                            } else {
                                Text(ending.label)
                            }
                        }
                    }
                } label: {
                    Label(viewModel.lineEnding.label, systemImage: "return")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Toggle("定时", isOn: $viewModel.autoSendEnabled)
                    .toggleStyle(.checkbox)
                    .disabled(!viewModel.isConnected)
                if viewModel.autoSendEnabled {
                    TextField("间隔(秒)", value: $viewModel.autoSendInterval, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }

                Menu {
                    if viewModel.sendHistory.isEmpty {
                        Text("暂无历史")
                    } else {
                        ForEach(viewModel.sendHistory, id: \.self) { item in
                            Button(item) { viewModel.sendText = item }
                        }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .menuStyle(.borderlessButton)
                .help("发送历史")

                Button(action: viewModel.toggleLogging) {
                    Image(systemName: viewModel.isLogging ? "stop.circle.fill" : "record.circle")
                        .foregroundColor(viewModel.isLogging ? .red : .secondary)
                }
                .buttonStyle(.bordered)
                .help(viewModel.isLogging ? "停止记录" : "开始记录到文件")

                Button {
                    viewModel.exportMessages()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .help("导出当前会话")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: TerminalViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("高级设置")
                .font(.headline)

            Form {
                Picker("数据位", selection: $viewModel.config.dataBits) {
                    Text("5").tag(5)
                    Text("6").tag(6)
                    Text("7").tag(7)
                    Text("8").tag(8)
                }

                Picker("校验位", selection: $viewModel.config.parity) {
                    ForEach(SerialConfig.Parity.allCases, id: \.self) { parity in
                        Text(parity.rawValue).tag(parity)
                    }
                }

                Picker("停止位", selection: $viewModel.config.stopBits) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                }

                Picker("流控制", selection: $viewModel.config.flowControl) {
                    ForEach(SerialConfig.FlowControl.allCases, id: \.self) { flow in
                        Text(flow.rawValue).tag(flow)
                    }
                }

                Picker("编码", selection: $viewModel.displayEncoding) {
                    ForEach(TerminalViewModel.DisplayEncoding.allCases) { enc in
                        Text(enc.label).tag(enc)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 300)

            HStack {
                Button("确定") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400, height: 320)
    }
}
