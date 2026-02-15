import AVFoundation
import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum DictationState {
        case idle
        case recording
        case transcribing
    }

    private let statusLabel = UILabel()
    private let nextKeyboardButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let spaceButton = UIButton(type: .system)
    private let returnButton = UIButton(type: .system)

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var transcriptionTask: Task<Void, Never>?
    private var idleStatusMessage = "Tap mic to dictate"

    private var dictationState: DictationState = .idle {
        didSet {
            updateMicAppearance()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        updateMicAppearance()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
    }

    deinit {
        cleanupSession()
    }

    private func buildUI() {
        view.backgroundColor = UIColor.systemGray6

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = idleStatusMessage

        configureKey(nextKeyboardButton, title: "globe", selector: #selector(handleNextKeyboard))
        configureKey(micButton, title: "mic", selector: #selector(handleMicToggle))
        configureKey(deleteButton, title: "del", selector: #selector(handleDelete))
        configureKey(spaceButton, title: "space", selector: #selector(handleSpace))
        configureKey(returnButton, title: "return", selector: #selector(handleReturn))

        micButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)

        let topRow = UIStackView(arrangedSubviews: [nextKeyboardButton, micButton, deleteButton])
        topRow.axis = .horizontal
        topRow.alignment = .fill
        topRow.distribution = .fillEqually
        topRow.spacing = 8

        let bottomRow = UIStackView(arrangedSubviews: [spaceButton, returnButton])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .fill
        bottomRow.distribution = .fillProportionally
        bottomRow.spacing = 8

        spaceButton.widthAnchor.constraint(equalTo: returnButton.widthAnchor, multiplier: 2.2).isActive = true

        let rows = UIStackView(arrangedSubviews: [statusLabel, topRow, bottomRow])
        rows.translatesAutoresizingMaskIntoConstraints = false
        rows.axis = .vertical
        rows.spacing = 8

        view.addSubview(rows)

        let height = view.heightAnchor.constraint(equalToConstant: 220)
        height.priority = .defaultHigh
        height.isActive = true

        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            rows.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            rows.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            rows.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),

            topRow.heightAnchor.constraint(equalToConstant: 54),
            bottomRow.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func configureKey(_ button: UIButton, title: String, selector: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 10
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        button.addTarget(self, action: selector, for: .touchUpInside)
    }

    private func updateMicAppearance() {
        switch dictationState {
        case .idle:
            micButton.backgroundColor = .white
            micButton.tintColor = .label
            statusLabel.text = idleStatusMessage
        case .recording:
            micButton.backgroundColor = .systemRed
            micButton.tintColor = .white
            statusLabel.text = "Listening... tap mic again to stop"
        case .transcribing:
            micButton.backgroundColor = .systemOrange
            micButton.tintColor = .white
            statusLabel.text = "Transcribing with OpenAI..."
        }
    }

    private func setIdleStatus(_ message: String) {
        idleStatusMessage = message
        if dictationState == .idle {
            statusLabel.text = message
        }
    }

    @objc private func handleNextKeyboard() {
        advanceToNextInputMode()
    }

    @objc private func handleDelete() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func handleSpace() {
        textDocumentProxy.insertText(" ")
    }

    @objc private func handleReturn() {
        textDocumentProxy.insertText("\n")
    }

    @objc private func handleMicToggle() {
        switch dictationState {
        case .idle:
            Task { [weak self] in
                await self?.requestMicrophoneAndStart()
            }
        case .recording:
            stopRecordingAndTranscribe()
        case .transcribing:
            break
        }
    }

    @MainActor
    private func requestMicrophoneAndStart() async {
        let micAllowed = await requestMicrophoneAuthorizationIfNeeded()
        guard micAllowed else {
            setIdleStatus("Microphone permission denied")
            return
        }

        do {
            try startRecording()
        } catch {
            setIdleStatus("Could not start recording")
            dictationState = .idle
        }
    }

    private func requestMicrophoneAuthorizationIfNeeded() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        let current = session.recordPermission
        if current == .granted {
            return true
        }
        if current == .denied {
            return false
        }

        return await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startRecording() throws {
        cleanupSession()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zypper-dictation-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: tempURL, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw DictationError.recordingUnavailable
        }

        audioRecorder = recorder
        recordingURL = tempURL
        setIdleStatus("Tap mic to dictate")
        dictationState = .recording
    }

    private func stopRecordingAndTranscribe() {
        guard dictationState == .recording else { return }
        guard let recorder = audioRecorder, let fileURL = recordingURL else {
            setIdleStatus("No active recording")
            dictationState = .idle
            return
        }

        dictationState = .transcribing
        recorder.stop()
        audioRecorder = nil
        deactivateAudioSession()

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            await self?.transcribeAndInsert(fileURL: fileURL)
        }
    }

    @MainActor
    private func transcribeAndInsert(fileURL: URL) async {
        defer {
            transcriptionTask = nil
            try? FileManager.default.removeItem(at: fileURL)
            recordingURL = nil
            dictationState = .idle
        }

        do {
            let config = try OpenAIKeyboardConfig.load()
            let rawTranscript = try await OpenAITranscriber.transcribe(fileURL: fileURL, config: config)

            if Task.isCancelled {
                setIdleStatus("Canceled")
                return
            }

            let transcript = TranscriptPostProcessor.apply(rawTranscript, language: config.language)
            guard !transcript.isEmpty else {
                setIdleStatus("Empty transcript")
                return
            }

            textDocumentProxy.insertText(transcript)
            setIdleStatus("Inserted. Tap mic to dictate")
        } catch let error as OpenAIKeyboardConfigError {
            setIdleStatus(error.localizedDescription)
        } catch {
            setIdleStatus("Transcription failed")
        }
    }

    private func cleanupSession() {
        transcriptionTask?.cancel()
        transcriptionTask = nil

        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
        }
        audioRecorder = nil

        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
        }

        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore cleanup errors in keyboard extension.
        }
    }
}

private enum DictationError: Error {
    case recordingUnavailable
}
