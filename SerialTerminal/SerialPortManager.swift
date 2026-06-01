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
    private var receiveBuffer = Data()
    private let bufferLock = NSLock()

    var onDataReceived: ((Data, Date) -> Void)?
    var onError: ((String) -> Void)?

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
        flushTimer?.schedule(deadline: .now(), repeating: .milliseconds(50))
        flushTimer?.setEventHandler { [weak self] in
            self?.flushBuffer()
        }
        flushTimer?.resume()

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

        DispatchQueue.main.async {
            self.isConnected = false
            self.delegate?.serialPortDidDisconnect()
        }
    }

    func send(_ data: Data) {
        guard fileDescriptor != -1 else { return }

        data.withUnsafeBytes { buffer in
            if let baseAddress = buffer.baseAddress {
                _ = Darwin.write(fileDescriptor, baseAddress, buffer.count)
            }
        }
    }

    func send(_ string: String) {
        if let data = string.data(using: .utf8) {
            send(data)
        }
    }

    private func readAvailableData() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fileDescriptor, &buffer, buffer.count)

        if bytesRead > 0 {
            let data = Data(buffer[0..<bytesRead])
            bufferLock.lock()
            receiveBuffer.append(data)

            let hasNewline = receiveBuffer.contains { $0 == 10 || $0 == 13 }
            if hasNewline {
                let timestamp = Date()
                let dataToSend = receiveBuffer
                receiveBuffer = Data()
                bufferLock.unlock()
                DispatchQueue.main.async {
                    self.onDataReceived?(dataToSend, timestamp)
                    self.delegate?.serialPortDidReceive(data: dataToSend, timestamp: timestamp)
                }
            } else {
                bufferLock.unlock()
            }
        } else if bytesRead < 0 && errno != EAGAIN && errno != EWOULDBLOCK {
            DispatchQueue.main.async {
                self.onError?("读取错误: \(String(cString: strerror(errno)))")
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
