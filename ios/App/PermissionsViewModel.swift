import AVFoundation

@MainActor
final class PermissionsViewModel: ObservableObject {
    @Published private(set) var micAuthorized = false
    @Published private(set) var statusMessage = "Tap Grant Permissions to prepare dictation."

    func refresh() {
        micAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        statusMessage = statusSummary()
    }

    func requestAll() async {
        let micGranted = await requestMicrophoneAuthorizationIfNeeded()

        micAuthorized = micGranted
        statusMessage = statusSummary()
    }

    private func statusSummary() -> String {
        if micAuthorized {
            return "Microphone permission granted. Enable the keyboard in iOS Settings."
        }
        return "Microphone permission is missing."
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
