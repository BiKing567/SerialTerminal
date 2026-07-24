import Foundation
import IOKit
import IOKit.serial

private let B460800: speed_t = 0x10C
private let B921600: speed_t = 0x10D

struct SerialPortInfo: Identifiable, Hashable {
    let id: String
    let path: String
    let name: String

    init(path: String) {
        self.path = path
        self.id = path
        self.name = (path as NSString).lastPathComponent
    }
}

struct SerialConfig {
    var baudRate: Int = 9600
    var dataBits: Int = 8
    var parity: Parity = .none
    var stopBits: Int = 1
    var flowControl: FlowControl = .none

    enum Parity: String, CaseIterable {
        case none = "None"
        case odd = "Odd"
        case even = "Even"
    }

    enum FlowControl: String, CaseIterable {
        case none = "None"
        case hardware = "Hardware"
        case software = "Software"
    }

    static let baudRates = [300, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
}

protocol SerialPortManagerDelegate: AnyObject {
    func serialPortDidReceive(data: Data, timestamp: Date)
    func serialPortDidConnect()
    func serialPortDidDisconnect()
    func serialPortDidEncounterError(_ error: String)
}

class SerialPortManager: ObservableObject {
    @Published var availablePorts: [SerialPortInfo] = []
    @Published var isConnected: Bool = false
    @Published var config: SerialConfig = SerialConfig()

    weak var delegate: SerialPortManagerDelegate?

    private var fileDescriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var readQueue: DispatchQueue?
    private var logQueue: DispatchQueue
    private var flushTimer: DispatchSourceTimer?
    private var healthCheckTimer: DispatchSourceTimer?
    private var receiveBuffer = Data()
    private let bufferLock = NSLock()
    private var isDisconnecting = false

    var onDataReceived: ((Data, Date) -> Void)?
    var onError: ((String) -> Void)?
    var onDisconnectedMessage: ((String) -> Void)?

    init() {
        logQueue = DispatchQueue(label: "com.serialdebug.logqueue")
        refreshPorts()
    }

    func refreshPorts() {
        var ports: [SerialPortInfo] = []
        let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
        matchingDict[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        if result == KERN_SUCCESS {
            var service: io_object_t = IOIteratorNext(iterator)
            while service != 0 {
                if let path = IORegistryEntryCreateCFProperty(service, kIOCalloutDeviceKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                    ports.append(SerialPortInfo(path: path))
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }

        if ports.isEmpty {
            let devPath = "/dev"
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: devPath) {
                let patterns = ["cu.usbserial", "cu.usbmodem", "cu.wchusbserial", "cu.SLAB_USBtoUART", "cu.BLTH", "cu.DEVICE"]
                for item in contents where item.hasPrefix("cu.") {
                    for pattern in patterns {
                        if item.lowercased().contains(pattern.lowercased()) {
                            ports.append(SerialPortInfo(path: "\(devPath)/\(item)"))
                            break
                        }
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.availablePorts = ports.sorted { $0.path < $1.path }
        }
    }

    func connect(to port: SerialPortInfo) {
        disconnect()

        fileDescriptor = open(port.path, O_RDWR | O_NOCTTY | O_NONBLOCK)

        guard fileDescriptor != -1 else {
            onError?("无法打开串口: \(String(cString: strerror(errno)))")
            return
        }

        var options = termios()
        if tcgetattr(fileDescriptor, &options) != 0 {
            onError?("获取串口属性失败")
            close(fileDescriptor)
            fileDescriptor = -1
            return
        }

        cfsetispeed(&options, speedConstant(for: config.baudRate))
        cfsetospeed(&options, speedConstant(for: config.baudRate))

        options.c_cflag |= UInt(CLOCAL | CREAD)

        options.c_cflag &= ~UInt(PARENB)
        switch config.parity {
        case .none: break
        case .odd: options.c_cflag |= UInt(PARODD)
        case .even: options.c_cflag |= UInt(PARENB)
        }

        options.c_cflag &= ~UInt(CSIZE)
        switch config.dataBits {
        case 5: options.c_cflag |= UInt(CS5)
        case 6: options.c_cflag |= UInt(CS6)
        case 7: options.c_cflag |= UInt(CS7)
        default: options.c_cflag |= UInt(CS8)
        }

        switch config.stopBits {
        case 2: options.c_cflag |= UInt(CSTOPB)
        default: options.c_cflag &= ~UInt(CSTOPB)
        }

        switch config.flowControl {
        case .hardware: options.c_cflag |= UInt(CRTSCTS)
        case .software:
            options.c_iflag |= UInt(IXON | IXOFF | IXANY)
        case .none:
            options.c_cflag &= ~UInt(CRTSCTS)
            options.c_iflag &= ~UInt(IXON | IXOFF | IXANY)
        }

        options.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ISIG)
        options.c_oflag &= ~UInt(OPOST)

        options.c_cc.16 = 0
        options.c_cc.17 = 1

        if tcsetattr(fileDescriptor, TCSANOW, &options) != 0 {
            onError?("设置串口属性失败")
            close(fileDescriptor)
            fileDescriptor = -1
            return
        }

        tcflush(fileDescriptor, TCIOFLUSH)

        receiveBuffer = Data()

        flushTimer = DispatchSource.makeTimerSource(queue: logQueue)
        flushTimer?.setEventHandler { [weak self] in
            self?.flushBuffer()
        }
        // Start with distant future - won't fire until data arrives
        flushTimer?.schedule(deadline: .distantFuture, repeating: .never)
        flushTimer?.resume()

        startHealthCheck()

        readQueue = DispatchQueue(label: "com.serialdebug.readqueue", qos: .userInteractive)
        readSource = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: readQueue)

        readSource?.setEventHandler { [weak self] in
            self?.readAvailableData()
        }

        readSource?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
            }
        }

        readSource?.resume()

        DispatchQueue.main.async {
            self.isConnected = true
            self.delegate?.serialPortDidConnect()
        }
    }

    func disconnect() {
        stopHealthCheck()

        flushTimer?.cancel()
        flushTimer = nil

        flushBuffer()

        readSource?.cancel()
        readSource = nil
        readQueue = nil

        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }

        isDisconnecting = false

        DispatchQueue.main.async {
            self.isConnected = false
            self.delegate?.serialPortDidDisconnect()
        }
    }

    func send(_ data: Data) {
        guard fileDescriptor != -1, isConnected else { return }

        data.withUnsafeBytes { buffer in
            if let baseAddress = buffer.baseAddress {
                let written = Darwin.write(fileDescriptor, baseAddress, buffer.count)
                if written < 0 {
                    let err = errno
                    if err == EIO || err == EBADF || err == ENXIO {
                        if self.isDisconnecting { return }
                        self.isDisconnecting = true
                        DispatchQueue.main.async {
                            self.onDisconnectedMessage?("检测到设备被移除，已自动断开连接")
                            self.disconnect()
                        }
                    }
                }
            }
        }
    }

    func send(_ string: String) {
        if let data = string.data(using: .utf8) {
            send(data)
        }
    }

    private func readAvailableData() {
        guard !isDisconnecting else { return }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fileDescriptor, &buffer, buffer.count)

        if bytesRead > 0 {
            let data = Data(buffer[0..<bytesRead])
            bufferLock.lock()
            receiveBuffer.append(data)

            // Debounce: reset the flush timer - fires 200ms after last data arrival
            flushTimer?.schedule(deadline: .now() + .milliseconds(200), repeating: .never)

            // Flush immediately when newline is detected
            let hasNewline = receiveBuffer.contains { $0 == 10 || $0 == 13 }
            bufferLock.unlock()

            if hasNewline {
                flushBuffer()
            }
        } else if bytesRead == 0 {
            // EOF - device disconnected
            isDisconnecting = true
            DispatchQueue.main.async {
                self.onDisconnectedMessage?("检测到设备被移除，已自动断开连接")
                self.disconnect()
            }
        } else if bytesRead < 0 {
            let err = errno
            if err == EAGAIN || err == EWOULDBLOCK {
                return
            }
            if err == EIO || err == EBADF || err == ENXIO {
                isDisconnecting = true
                DispatchQueue.main.async {
                    self.onDisconnectedMessage?("检测到设备被移除，已自动断开连接")
                    self.disconnect()
                }
            } else {
                DispatchQueue.main.async {
                    self.onError?("读取错误: \(String(cString: strerror(err)))")
                }
            }
        }
    }

    private func flushBuffer() {
        bufferLock.lock()
        if receiveBuffer.isEmpty {
            bufferLock.unlock()
            return
        }
        let data = receiveBuffer
        receiveBuffer = Data()
        bufferLock.unlock()

        DispatchQueue.main.async {
            self.onDataReceived?(data, Date())
            self.delegate?.serialPortDidReceive(data: data, timestamp: Date())
        }
    }

    private func startHealthCheck() {
        stopHealthCheck()
        let timer = DispatchSource.makeTimerSource(queue: logQueue)
        timer.schedule(deadline: .now() + 2, repeating: .seconds(2))
        timer.setEventHandler { [weak self] in
            guard let self = self, self.fileDescriptor != -1 else { return }
            var temp = termios()
            let result = tcgetattr(self.fileDescriptor, &temp)
            if result != 0 {
                let err = errno
                if err == EIO || err == EBADF || err == ENODEV || err == ENXIO {
                    if self.isDisconnecting { return }
                    self.isDisconnecting = true
                    DispatchQueue.main.async {
                        self.onDisconnectedMessage?("检测到设备被移除，已自动断开连接")
                        self.disconnect()
                    }
                }
            }
        }
        healthCheckTimer = timer
        timer.resume()
    }

    private func stopHealthCheck() {
        healthCheckTimer?.cancel()
        healthCheckTimer = nil
    }

    private func speedConstant(for baudRate: Int) -> speed_t {
        switch baudRate {
        case 300: return speed_t(B300)
        case 1200: return speed_t(B1200)
        case 2400: return speed_t(B2400)
        case 4800: return speed_t(B4800)
        case 9600: return speed_t(B9600)
        case 19200: return speed_t(B19200)
        case 38400: return speed_t(B38400)
        case 57600: return speed_t(B57600)
        case 115200: return speed_t(B115200)
        case 230400: return speed_t(B230400)
        case 460800: return speed_t(B460800)
        case 921600: return speed_t(B921600)
        default: return speed_t(B115200)
        }
    }

    deinit {
        disconnect()
    }
}
