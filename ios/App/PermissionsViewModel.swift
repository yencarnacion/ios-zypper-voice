import AVFoundation
import Speech

@MainActor
final class PermissionsViewModel: ObservableObject {
    @Published private(set) var speechAuthorized = false
    @Published private(set) var micAuthorized = false
    @Published private(set) var statusMessage = "Tap Grant Permissions to prepare dictation."

    func refresh() {
        speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        micAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        statusMessage = statusSummary()
    }

    func requestAll() async {
        let speechStatus = await requestSpeechAuthorizationIfNeeded()
        let micGranted = await requestMicrophoneAuthorizationIfNeeded()

        speechAuthorized = speechStatus == .authorized
        micAuthorized = micGranted
        statusMessage = statusSummary()
    }

    private func statusSummary() -> String {
        switch (speechAuthorized, micAuthorized) {
        case (true, true):
            return "Permissions granted. Enable the keyboard in iOS Settings."
        case (false, false):
            return "Speech and Microphone permissions are missing."
        case (false, true):
            return "Speech Recognition permission is missing."
        case (true, false):
            return "Microphone permission is missing."
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
}
