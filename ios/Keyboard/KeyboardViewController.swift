import AVFoundation
import Speech
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

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInputTap = false
    private var finalizeFallbackWorkItem: DispatchWorkItem?

    private var renderedTranscript = ""
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
        cleanupRecognitionSession(cancelTask: true)
    }

    private func buildUI() {
        view.backgroundColor = UIColor.systemGray6

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Tap mic to dictate"

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
            statusLabel.text = "Tap mic to dictate"
        case .recording:
            micButton.backgroundColor = .systemRed
            micButton.tintColor = .white
            statusLabel.text = "Listening... tap mic again to stop"
        case .transcribing:
            micButton.backgroundColor = .systemOrange
            micButton.tintColor = .white
            statusLabel.text = "Transcribing..."
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
                await self?.requestPermissionsAndStart()
            }
        case .recording:
            stopRecording()
        case .transcribing:
            // Ignore tap while finalizing to avoid corrupting active transcript updates.
            break
        }
    }

    @MainActor
    private func requestPermissionsAndStart() async {
        let speechStatus = await requestSpeechAuthorizationIfNeeded()
        guard speechStatus == .authorized else {
            statusLabel.text = "Speech permission denied"
            return
        }

        let micAllowed = await requestMicrophoneAuthorizationIfNeeded()
        guard micAllowed else {
            statusLabel.text = "Microphone permission denied"
            return
        }

        do {
            try startRecording()
        } catch {
            statusLabel.text = "Could not start recording"
        }
    }

    private func requestSpeechAuthorizationIfNeeded() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        if current != .notDetermined {
            return current
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
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
        cleanupRecognitionSession(cancelTask: true)
        renderedTranscript = ""

        let languageCode = textInputMode?.primaryLanguage ?? Locale.preferredLanguages.first ?? "en-US"
        let locale = Locale(identifier: languageCode)
        speechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw DictationError.speechUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        removeInputTapIfNeeded()
        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        hasInputTap = true

        audioEngine.prepare()
        try audioEngine.start()

        dictationState = .recording

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                DispatchQueue.main.async {
                    self.renderTranscript(result.bestTranscription.formattedString)
                    if result.isFinal {
                        self.finishRecognitionSession()
                    }
                }
            }

            if error != nil {
                DispatchQueue.main.async {
                    self.finishRecognitionSession()
                }
            }
        }
    }

    private func stopRecording() {
        guard dictationState == .recording else { return }
        dictationState = .transcribing

        audioEngine.stop()
        removeInputTapIfNeeded()
        recognitionRequest?.endAudio()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.dictationState == .transcribing else { return }
            self.finishRecognitionSession()
        }
        finalizeFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    private func renderTranscript(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        applyTranscriptDelta(from: renderedTranscript, to: text)
        renderedTranscript = text
    }

    private func applyTranscriptDelta(from oldText: String, to newText: String) {
        if oldText == newText {
            return
        }

        let oldChars = Array(oldText)
        let newChars = Array(newText)

        var prefixLength = 0
        while prefixLength < oldChars.count,
              prefixLength < newChars.count,
              oldChars[prefixLength] == newChars[prefixLength] {
            prefixLength += 1
        }

        let deleteCount = oldChars.count - prefixLength
        if deleteCount > 0 {
            for _ in 0..<deleteCount {
                textDocumentProxy.deleteBackward()
            }
        }

        if prefixLength < newChars.count {
            let suffix = String(newChars[prefixLength...])
            textDocumentProxy.insertText(suffix)
        }
    }

    private func finishRecognitionSession() {
        finalizeFallbackWorkItem?.cancel()
        finalizeFallbackWorkItem = nil
        cleanupRecognitionSession(cancelTask: false)
        dictationState = .idle
        renderedTranscript = ""
    }

    private func cleanupRecognitionSession(cancelTask: Bool) {
        finalizeFallbackWorkItem?.cancel()
        finalizeFallbackWorkItem = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeInputTapIfNeeded()

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if cancelTask {
            recognitionTask?.cancel()
        }
        recognitionTask = nil
        speechRecognizer = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore audio-session cleanup failures in keyboard extension.
        }
    }

    private func removeInputTapIfNeeded() {
        guard hasInputTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasInputTap = false
    }
}

private enum DictationError: Error {
    case speechUnavailable
}
