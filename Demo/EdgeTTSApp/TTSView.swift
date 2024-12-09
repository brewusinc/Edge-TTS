import AVKit
import SwiftUI

public struct TTSView: View {
    @StateObject private var viewModel = TTSViewModel()
    @StateObject private var audioDelegate = AudioPlayerDelegate()
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false

    public init() {}

    public var body: some View {
        Form {
            Section("Text Input") {
                TextEditor(text: $viewModel.text)
                    .frame(height: 100)
            }

            Section("Voice Settings") {
                HStack {
                    Text("Voice")
                        .frame(width: 60, alignment: .leading)
                    Picker("", selection: $viewModel.voice) {
                        ForEach(viewModel.availableVoices, id: \.shortName) { voice in
                            Text("\(voice.friendlyName) (\(voice.locale))")
                                .tag(voice.shortName)
                        }
                    }
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Rate")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: {
                                Double(viewModel.rate.replacingOccurrences(of: "%", with: "")) ?? 0
                            },
                            set: { viewModel.rate = "\(Int($0))%" }
                        ), in: -50...100)
                    Text(viewModel.rate)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Pitch")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: {
                                Double(viewModel.pitch.replacingOccurrences(of: "Hz", with: ""))
                                    ?? 0
                            },
                            set: { viewModel.pitch = "\(Int($0))Hz" }
                        ), in: -50...50)
                    Text(viewModel.pitch)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Volume")
                        .frame(width: 60, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: {
                                Double(viewModel.volume.replacingOccurrences(of: "%", with: ""))
                                    ?? 0
                            },
                            set: { viewModel.volume = "\(Int($0))%" }
                        ), in: -50...50)
                    Text(viewModel.volume)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Boundary")
                        .frame(width: 60, alignment: .leading)
                    Picker("", selection: $viewModel.boundaryType) {
                        ForEach(viewModel.boundaryOptions) { option in
                            Text(option.title).tag(option.type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)
            }

            Section("Export Settings") {
                Toggle("Export JSON", isOn: $viewModel.enableJSON)
                Toggle("Export SRT", isOn: $viewModel.enableSRT)

                if viewModel.lastConvertedURL != nil {
                    Button(action: {
                        viewModel.exportFile(from: viewModel.lastConvertedURL!)
                    }) {
                        Label("Export Audio", systemImage: "square.and.arrow.up")
                    }

                    if viewModel.enableJSON, let jsonURL = viewModel.getJSONURL() {
                        Button(action: {
                            viewModel.exportFile(from: jsonURL)
                        }) {
                            Label("Export JSON", systemImage: "square.and.arrow.up")
                        }
                    }

                    if viewModel.enableSRT, let srtURL = viewModel.getSRTURL() {
                        Button(action: {
                            viewModel.exportFile(from: srtURL)
                        }) {
                            Label("Export SRT", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }

            Section {
                Button(action: {
                    if isPlaying {
                        audioPlayer?.stop()
                        isPlaying = false
                    } else {
                        Task {
                            if let url = await viewModel.convertToSpeech() {
                                do {
                                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                                    audioPlayer?.delegate = audioDelegate
                                    audioDelegate.onPlaybackFinished = {
                                        isPlaying = false
                                    }
                                    audioPlayer?.play()
                                    isPlaying = true
                                } catch {
                                    print("Error playing audio: \(error)")
                                }
                            }
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isConverting {
                            ProgressView()
                                .controlSize(.small)
                            Text("Converting...")
                        } else if isPlaying {
                            Label("Stop", systemImage: "stop.circle.fill")
                        } else {
                            Label("Convert & Play", systemImage: "play.circle.fill")
                        }
                    }
                    .frame(minWidth: 100)
                }
                .disabled(viewModel.text.isEmpty || viewModel.isConverting)
            }
        }
        .task {
            await viewModel.loadVoices()
        }
        #if os(iOS)
            .sheet(isPresented: $viewModel.showShareSheet) {
                if !viewModel.shareItems.isEmpty {
                    ShareSheet(activityItems: viewModel.shareItems)
                }
            }
        #endif
    }
}

#if os(iOS)
    struct ShareSheet: UIViewControllerRepresentable {
        let activityItems: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            let controller = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            return controller
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context)
        {}
    }
#endif

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate, ObservableObject {
    var onPlaybackFinished: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            DispatchQueue.main.async {
                self.onPlaybackFinished?()
            }
        }
    }
}
