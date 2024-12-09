import ArgumentParser
import EdgeTTS
import Foundation

protocol EdgeTTSCommand: AsyncParsableCommand {}

@main
struct EdgeTTSCLI: EdgeTTSCommand {
    static var configuration = CommandConfiguration(
        commandName: "edge-tts-cli",
        abstract: "A Swift implementation of Microsoft Edge TTS",
        version: "1.0.0",
        subcommands: [List.self, Speak.self]
    )
}

// MARK: - List Command
struct List: EdgeTTSCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all available voices"
    )

    @Option(name: .long, help: "Proxy URL (e.g. http://host:port)")
    var proxy: String?

    func run() async throws {
        // Create a temporary EdgeTTS instance to use its methods
        let tts = EdgeTTS(config: Configure())
        let voices = try await tts.fetchVoices(proxy: proxy)
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

// MARK: - Speak Command
struct Speak: EdgeTTSCommand {
    static var configuration = CommandConfiguration(
        commandName: "speak",
        abstract: "Convert text to speech"
    )

    @Option(name: .long, help: "Voice to use")
    var voice: String = "en-US-JennyNeural"

    @Option(name: .long, help: "Language to use")
    var lang: String = "en-US"

    @Option(name: .long, help: "Output format")
    var format: String = "audio-24khz-48kbitrate-mono-mp3"

    @Option(name: .long, help: "Output file name")
    var output: String = "output.mp3"

    @Option(name: .long, help: "Text to speak")
    var text: String?

    @Option(name: .long, help: "Input text file path")
    var file: String?

    @Option(name: .long, help: "Speech rate (e.g. +0%, -10%)")
    var rate: String = "+0%"

    @Option(name: .long, help: "Speech pitch (e.g. +0Hz, -10Hz)")
    var pitch: String = "+0Hz"

    @Option(name: .long, help: "Speech volume (e.g. +0%, -10%)")
    var volume: String = "+0%"

    @Option(name: .long, help: "Boundary type (sentence or word)")
    var boundary: String = "sentence"

    @Flag(name: .long, help: "Save timing info as JSON")
    var saveJSON: Bool = false

    @Flag(name: .long, help: "Save timing info as SRT")
    var saveSRT: Bool = false

    @Option(name: .long, help: "Proxy URL (e.g. http://host:port)")
    var proxy: String?

    func validate() throws {
        if text != nil && file != nil {
            throw ValidationError("Cannot provide both --text and --file options")
        }

        if !["sentence", "word"].contains(boundary.lowercased()) {
            throw ValidationError("Boundary type must be either 'sentence' or 'word'")
        }
    }

    func run() async throws {
        // Get text to convert
        let textToConvert: String
        if let filePath = file {
            do {
                textToConvert = try String(contentsOfFile: filePath, encoding: .utf8)
                print("Reading text from file: \(filePath)")
            } catch {
                throw ValidationError("Failed to read file: \(error.localizedDescription)")
            }
        } else if let inputText = text {
            textToConvert = inputText
        } else {
            print("Please enter text to convert (press Enter when done):")
            guard let userInput = readLine(), !userInput.isEmpty else {
                throw ValidationError("No text content provided")
            }
            textToConvert = userInput
        }

        // Create configuration
        let boundaryType: Configure.BoundaryType =
            boundary.lowercased() == "word" ? .word : .sentence
        let config = Configure(
            voice: voice,
            lang: lang,
            outputFormat: format,
            saveJSON: saveJSON,
            saveSRT: saveSRT,
            proxy: proxy,
            rate: rate,
            pitch: pitch,
            volume: volume,
            boundaryType: boundaryType
        )

        // Create TTS instance and process
        let tts = EdgeTTS(config: config)
        print("Converting text to speech...")
        print("Text: \(textToConvert)")
        print("Output: \(output)")
        print("Boundary type: \(boundary)")

        try await tts.ttsPromise(text: textToConvert, audioPath: output)
        print("Conversion completed successfully!")
        if saveJSON {
            print("Metadata saved to: \(output).json")
        }
        if saveSRT {
            print("Subtitles saved to: \(output).srt")
        }
    }
}
