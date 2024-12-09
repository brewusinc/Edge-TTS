import CryptoKit
import Foundation
import Network

// MARK: - Constants
public struct EdgeTTSConstants {
    public static let CHROMIUM_FULL_VERSION = "130.0.2849.68"
    public static let TRUSTED_CLIENT_TOKEN = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    public static let WINDOWS_FILE_TIME_EPOCH: Int64 = 11_644_473_600
}

// MARK: - Models
public struct SubLine: Codable {
    public var part: String
    public var start: Int
    public var end: Int

    public init(part: String, start: Int, end: Int) {
        self.part = part
        self.start = start
        self.end = end
    }
}

public struct Configure {
    public var voice: String
    public var lang: String
    public var outputFormat: String
    public var saveJSON: Bool
    public var saveSRT: Bool
    public var proxy: String?
    public var rate: String
    public var pitch: String
    public var volume: String
    public var timeout: TimeInterval
    public var boundaryType: BoundaryType

    public enum BoundaryType {
        case sentence
        case word

        public var configValue: (sentenceBoundary: String, wordBoundary: String) {
            switch self {
            case .sentence:
                return ("true", "false")
            case .word:
                return ("false", "true")
            }
        }
    }

    public init(
        voice: String = "en-US-JennyNeural",
        lang: String = "en-US",
        outputFormat: String = "audio-24khz-48kbitrate-mono-mp3",
        saveJSON: Bool = false,
        saveSRT: Bool = false,
        proxy: String? = nil,
        rate: String = "+0%",
        pitch: String = "+0Hz",
        volume: String = "+0%",
        timeout: TimeInterval = 60,
        boundaryType: BoundaryType = .sentence
    ) {
        self.voice = voice
        self.lang = lang
        self.outputFormat = outputFormat
        self.saveJSON = saveJSON
        self.saveSRT = saveSRT
        self.proxy = proxy
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
        self.timeout = timeout
        self.boundaryType = boundaryType
    }
}

// MARK: - DRM Helper
class DRMHelper {
    static func generateSecMsGecToken() -> String {
        let currentTime = Int64(Date().timeIntervalSince1970)
        let ticks = (currentTime + EdgeTTSConstants.WINDOWS_FILE_TIME_EPOCH) * 10_000_000
        let roundedTicks = ticks - (ticks % 3_000_000_000)

        let strToHash = "\(roundedTicks)\(EdgeTTSConstants.TRUSTED_CLIENT_TOKEN)"
        guard let data = strToHash.data(using: .ascii) else {
            return ""
        }

        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02X", $0) }.joined()
    }
}

// MARK: - WebSocket Client
class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private var isConnected = false
    private var messageHandler: ((Result<URLSessionWebSocketTask.Message, Error>) -> Void)?
    private let proxy: String?

    init(proxy: String? = nil) {
        self.proxy = proxy
        super.init()
    }

    func connect(url: URL) async throws {
        // Create custom URLSessionConfiguration
        let configuration = URLSessionConfiguration.default
        if let proxyString = proxy {
            // Parse proxy string (format: "http://host:port" or "socks5://host:port")
            if let proxyURL = URL(string: proxyString) {
                let proxyHost = proxyURL.host ?? ""
                let proxyPort = proxyURL.port ?? 0

                var proxyType: String
                switch proxyURL.scheme?.lowercased() {
                case "http", "https":
                    proxyType = "HTTPProxy"
                case "socks", "socks5":
                    proxyType = "SOCKSProxy"
                default:
                    proxyType = "HTTPProxy"
                }

                configuration.connectionProxyDictionary = [
                    proxyType: proxyHost,
                    "\(proxyType)Port": proxyPort,
                ]
            }
        }

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0",
            forHTTPHeaderField: "User-Agent")
        request.setValue(
            "chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")

        webSocket = session.webSocketTask(with: request)
        webSocket?.resume()

        try await withCheckedThrowingContinuation { continuation in
            messageHandler = { [weak self] result in
                switch result {
                case .success:
                    self?.isConnected = true
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func send(_ message: String) async throws {
        try await webSocket?.send(.string(message))
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await webSocket?.receive() ?? URLSessionWebSocketTask.Message.string("")
    }

    func close() {
        webSocket?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - URLSessionWebSocketDelegate
    func urlSession(
        _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        messageHandler?(.success(.string("Connected")))
    }

    func urlSession(
        _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
    ) {
        isConnected = false
    }
}

// MARK: - Edge TTS
public class EdgeTTS {
    private let config: Configure

    public init(config: Configure = Configure()) {
        self.config = config
    }

    private func connectWebSocket() async throws -> WebSocketClient {
        let wsClient = WebSocketClient(proxy: config.proxy)
        let urlString =
            "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(EdgeTTSConstants.TRUSTED_CLIENT_TOKEN)&Sec-MS-GEC=\(DRMHelper.generateSecMsGecToken())&Sec-MS-GEC-Version=1-\(EdgeTTSConstants.CHROMIUM_FULL_VERSION)"

        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "EdgeTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        try await wsClient.connect(url: url)

        // Send initial configuration
        let boundaries = config.boundaryType.configValue
        let configMessage = """
                Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n
                {
                    "context": {
                        "synthesis": {
                            "audio": {
                                "metadataoptions": {
                                    "sentenceBoundaryEnabled": "\(boundaries.sentenceBoundary)",
                                    "wordBoundaryEnabled": "\(boundaries.wordBoundary)"
                                },
                                "outputFormat": "\(config.outputFormat)"
                            }
                        }
                    }
                }
            """
        try await wsClient.send(configMessage)

        return wsClient
    }

    private func saveJSONFile(_ subFile: [SubLine], text: String, audioPath: String) throws {
        let url = URL(fileURLWithPath: audioPath)
        let subPath = url.deletingPathExtension().appendingPathExtension("json").path
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let jsonData = try encoder.encode(subFile)
        try jsonData.write(to: URL(fileURLWithPath: subPath))
    }

    private func saveSRTFile(_ subFile: [SubLine], text: String, audioPath: String) throws {
        let url = URL(fileURLWithPath: audioPath)
        let srtPath = url.deletingPathExtension().appendingPathExtension("srt").path
        var srtContent = ""

        // Iterate through each subtitle entry to generate SRT format
        for (index, line) in subFile.enumerated() {
            // 1. Subtitle number
            srtContent += "\(index + 1)\n"

            // 2. Timestamp format: 00:00:00,000 --> 00:00:00,000
            let startTime = formatSRTTime(line.start)
            let endTime = formatSRTTime(line.end)
            srtContent += "\(startTime) --> \(endTime)\n"

            // 3. Subtitle text
            srtContent += "\(line.part)\n\n"
        }

        // Write file
        try srtContent.write(to: URL(fileURLWithPath: srtPath), atomically: true, encoding: .utf8)
    }

    // Convert milliseconds to SRT time format
    private func formatSRTTime(_ milliseconds: Int) -> String {
        let hours = milliseconds / 3_600_000
        let minutes = (milliseconds % 3_600_000) / 60000
        let seconds = (milliseconds % 60000) / 1000
        let millis = milliseconds % 1000

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }

    public func ttsPromise(text: String, audioPath: String) async throws {
        let webSocket = try await connectWebSocket()

        defer {
            webSocket.close()
        }

        var audioData = Data()
        var subFile: [SubLine] = []

        let task = Task {
            let requestId = UUID().uuidString
            let ssmlMessage = """
                    X-RequestId:\(requestId)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n
                    <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="\(config.lang)">
                        <voice name="\(config.voice)">
                            <prosody rate="\(config.rate)" pitch="\(config.pitch)" volume="\(config.volume)">
                                \(text)
                            </prosody>
                        </voice>
                    </speak>
                """

            try await webSocket.send(ssmlMessage)

            while true {
                let message = try await webSocket.receive()
                switch message {
                case .data(let data):
                    if let dataStr = String(data: data, encoding: .utf8),
                        dataStr.contains("Path:audio\r\n")
                    {
                        let separator = "Path:audio\r\n"
                        if let range = dataStr.range(of: separator) {
                            let audioStartIndex =
                                data.startIndex + range.upperBound.utf16Offset(in: dataStr)
                            let audioSubData = data[audioStartIndex...]
                            audioData.append(audioSubData)
                        }
                    } else {
                        // If cannot convert to string, it means it's pure binary audio data
                        audioData.append(data)
                    }
                case .string(let str):
                    if str.contains("Path:turn.end") {
                        try audioData.write(to: URL(fileURLWithPath: audioPath))
                        if config.saveJSON {
                            try saveJSONFile(subFile, text: text, audioPath: audioPath)
                        }
                        if config.saveSRT {
                            try saveSRTFile(subFile, text: text, audioPath: audioPath)
                        }
                        return
                    } else if str.contains("Path:audio.metadata") {
                        // Handle metadata and subtitles
                        let components = str.components(separatedBy: "\r\n")
                        if let lastComponent = components.last,
                            let jsonData = lastComponent.data(using: .utf8)
                        {
                            do {
                                if let metadata = try JSONSerialization.jsonObject(with: jsonData)
                                    as? [String: Any],
                                    let metadataArray = metadata["Metadata"] as? [[String: Any]]
                                {
                                    for element in metadataArray {
                                        if let data = element["Data"] as? [String: Any],
                                            let text = data["text"] as? [String: Any],
                                            let textContent = text["Text"] as? String,
                                            let offset = data["Offset"] as? Int,
                                            let duration = data["Duration"] as? Int
                                        {
                                            subFile.append(
                                                SubLine(
                                                    part: textContent,
                                                    start: Int(floor(Double(offset) / 10000)),
                                                    end: Int(
                                                        floor(Double(offset + duration) / 10000))
                                                ))
                                        }
                                    }
                                }
                            } catch {
                                print("Error parsing metadata: \(error)")
                            }
                        }
                    }
                @unknown default:
                    fatalError()
                }
            }
        }

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(config.timeout * 1_000_000_000))
            task.cancel()
            throw NSError(
                domain: "EdgeTTS", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Operation timed out"])
        }

        // Wait for either completion or timeout
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            timeoutTask.cancel()
        }
    }

    // MARK: - Voice Models
    public struct Voice: Codable {
        public let name: String
        public let shortName: String
        public let gender: String
        public let locale: String
        public let suggestedCodec: String
        public let friendlyName: String
        public let status: String
        public let voiceTag: VoiceTag

        public enum CodingKeys: String, CodingKey {
            case name = "Name"
            case shortName = "ShortName"
            case gender = "Gender"
            case locale = "Locale"
            case suggestedCodec = "SuggestedCodec"
            case friendlyName = "FriendlyName"
            case status = "Status"
            case voiceTag = "VoiceTag"
        }
    }

    public struct VoiceTag: Codable {
        public let contentCategories: [String]
        public let voicePersonalities: [String]

        public enum CodingKeys: String, CodingKey {
            case contentCategories = "ContentCategories"
            case voicePersonalities = "VoicePersonalities"
        }
    }

    // Get voice list
    public func fetchVoices(proxy: String? = nil) async throws -> [Voice] {
        let urlString =
            "https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=\(EdgeTTSConstants.TRUSTED_CLIENT_TOKEN)"
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "EdgeTTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(EdgeTTSConstants.CHROMIUM_FULL_VERSION) Safari/537.36 Edg/\(EdgeTTSConstants.CHROMIUM_FULL_VERSION)",
            forHTTPHeaderField: "User-Agent")

        // Create URLSession with proxy support
        let configuration = URLSessionConfiguration.default
        if let proxyString = proxy {
            if let proxyURL = URL(string: proxyString) {
                let proxyHost = proxyURL.host ?? ""
                let proxyPort = proxyURL.port ?? 0

                var proxyType: String
                switch proxyURL.scheme?.lowercased() {
                case "http", "https":
                    proxyType = "HTTPProxy"
                case "socks", "socks5":
                    proxyType = "SOCKSProxy"
                default:
                    proxyType = "HTTPProxy"
                }

                configuration.connectionProxyDictionary = [
                    proxyType: proxyHost,
                    "\(proxyType)Port": proxyPort,
                ]
            }
        }

        let session = URLSession(configuration: configuration)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([Voice].self, from: data)
    }

    // Print voice list
    public static func printVoicesByLanguage() async throws {
        // Create a temporary EdgeTTS instance to fetch voice list
        let tts = EdgeTTS()
        let voices = try await tts.fetchVoices()
        let groupedVoices = Dictionary(grouping: voices) { $0.locale }
        let sortedGroups = groupedVoices.sorted { $0.key < $1.key }

        for (locale, voices) in sortedGroups {
            print("\n\(locale) voices:")
            for voice in voices.sorted(by: { $0.shortName < $1.shortName }) {
                print("  \(voice.shortName) (\(voice.gender))")
                print("    \(voice.friendlyName)")
                if !voice.voiceTag.voicePersonalities.isEmpty {
                    print(
                        "    Personalities: \(voice.voiceTag.voicePersonalities.joined(separator: ", "))"
                    )
                }
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
