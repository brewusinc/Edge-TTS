import EdgeTTS
import Foundation

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@MainActor
public class TTSViewModel: ObservableObject {
    @Published public var text: String =
        "EdgeTTS is a Swift implementation of Microsoft Edge's Text-to-Speech (TTS) service. This library provides a simple and easy-to-use API interface that allows developers to seamlessly integrate high-quality text-to-speech functionality into Apple platform applications."
    @Published public var voice: String = "en-US-JennyNeural"
    @Published public var rate: String = "+0%"
    @Published public var pitch: String = "+0Hz"
    @Published public var volume: String = "+0%"
    @Published public var boundaryType: Configure.BoundaryType = .sentence
    @Published public var isConverting: Bool = false
    @Published public var availableVoices: [EdgeTTS.Voice] = []
    @Published public var error: Error?
    @Published public var enableJSON: Bool = false
    @Published public var enableSRT: Bool = false
    @Published public var lastConvertedURL: URL?

    #if os(iOS)
        @Published public var showShareSheet = false
        public var shareItems: [Any] = []
    #endif

    public struct BoundaryOption: Identifiable {
        public let id = UUID()
        public let title: String
        public let type: Configure.BoundaryType
    }

    public let boundaryOptions: [BoundaryOption] = [
        BoundaryOption(title: "Sentence", type: .sentence),
        BoundaryOption(title: "Word", type: .word),
    ]

    private let tts: EdgeTTS

    public init() {
        self.tts = EdgeTTS(config: Configure())
    }

    public func loadVoices() async {
        do {
            availableVoices = try await tts.fetchVoices()
        } catch {
            self.error = error
        }
    }

    public func convertToSpeech() async -> URL? {
        guard !text.isEmpty else { return nil }

        isConverting = true
        defer { isConverting = false }

        do {
            let config = Configure(
                voice: voice,
                saveJSON: enableJSON,
                saveSRT: enableSRT,
                rate: rate,
                pitch: pitch,
                volume: volume,
                boundaryType: boundaryType
            )

            let tts = EdgeTTS(config: config)

            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".mp3"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try await tts.ttsPromise(text: text, audioPath: fileURL.path)
            lastConvertedURL = fileURL
            return fileURL
        } catch {
            self.error = error
            return nil
        }
    }

    public func getJSONURL() -> URL? {
        guard let audioURL = lastConvertedURL else { return nil }
        return audioURL.deletingPathExtension().appendingPathExtension("json")
    }

    public func getSRTURL() -> URL? {
        guard let audioURL = lastConvertedURL else { return nil }
        return audioURL.deletingPathExtension().appendingPathExtension("srt")
    }

    public func exportFile(from url: URL) {
        #if os(iOS)
            shareItems = [url]
            showShareSheet = true
        #elseif os(macOS)
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.mp3, .json, .text]
            savePanel.nameFieldStringValue = url.lastPathComponent

            savePanel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) { response in
                if response == .OK {
                    if let saveURL = savePanel.url {
                        do {
                            if FileManager.default.fileExists(atPath: saveURL.path) {
                                try FileManager.default.removeItem(at: saveURL)
                            }
                            try FileManager.default.copyItem(at: url, to: saveURL)
                        } catch {
                            print("Error saving file: \(error)")
                        }
                    }
                }
            }
        #endif
    }
}
