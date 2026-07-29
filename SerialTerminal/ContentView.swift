import SwiftUI
import Combine

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
        serialManager.disconnect()
    }

    func send() {
        if showHexInput && !hexInputText.isEmpty {
            sendHex(hexInputText)
            hexInputText = ""
        } else if !sendText.isEmpty {
            let text = sendText.hasSuffix("\n") ? sendText : sendText + "\n"
            serialManager.send(text)
            addMessage(Data(text.utf8), timestamp: Date(), isIncoming: false)
            sendText = ""
        }
    }

    func sendHex(_ hexString: String) {
        let cleaned = hexString.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .uppercased()

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
        String(data.map { byte -> Character in
            if byte >= 32 && byte < 127 {
                return Character(UnicodeScalar(byte))
            } else if byte == 13 || byte == 10 {
                return byte == 13 ? "\u{21B5}" : "\u{21B5}"
            } else {
                return "."
            }
        })
    }

    private func formatHex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
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

                Button(action: viewModel.toggleLogging) {
                    Image(systemName: viewModel.isLogging ? "stop.circle.fill" : "record.circle")
                        .foregroundColor(viewModel.isLogging ? .red : .secondary)
                }
                .buttonStyle(.bordered)
                .help(viewModel.isLogging ? "停止记录" : "开始记录到文件")
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
