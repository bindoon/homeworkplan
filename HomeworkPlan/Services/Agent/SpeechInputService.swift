import AVFoundation
import Foundation
import Speech

enum SpeechInputPermissionStatus: Equatable {
    case authorized
    case denied
    case restricted
    case notDetermined
}

enum SpeechInputError: LocalizedError, Equatable {
    case permissionDenied
    case recognizerUnavailable
    case alreadyRecording
    case notRecording
    case audioEngineFailure
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未获得麦克风或语音识别权限，请使用文字输入"
        case .recognizerUnavailable:
            return "当前设备不支持中文语音识别"
        case .alreadyRecording:
            return "正在录音中"
        case .notRecording:
            return "未在录音"
        case .audioEngineFailure:
            return "无法启动麦克风"
        case .recognitionFailed(let detail):
            return "语音识别失败：\(detail)"
        }
    }
}

protocol SpeechAuthorizationProviding {
    func speechAuthorizationStatus() -> SFSpeechRecognizerAuthorizationStatus
    func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus
    func recordPermission() -> AVAudioApplication.recordPermission
    func requestRecordPermission() async -> Bool
}

struct SystemSpeechAuthorizationProvider: SpeechAuthorizationProviding {
    func speechAuthorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func recordPermission() -> AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    func requestRecordPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
}

@MainActor
@Observable
final class SpeechInputService {
    private(set) var isRecording = false
    private(set) var permissionStatus: SpeechInputPermissionStatus = .notDetermined
    private(set) var isAvailable = true
    private(set) var liveTranscript = ""

    private let locale: Locale
    private let authorizationProvider: SpeechAuthorizationProviding
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init(
        locale: Locale = Locale(identifier: "zh-CN"),
        authorizationProvider: SpeechAuthorizationProviding = SystemSpeechAuthorizationProvider()
    ) {
        self.locale = locale
        self.authorizationProvider = authorizationProvider
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        refreshAvailability()
    }

    func refreshAvailability() {
        permissionStatus = mapSpeechStatus(authorizationProvider.speechAuthorizationStatus())
        let micDenied = authorizationProvider.recordPermission() == .denied
        let speechDenied = permissionStatus == .denied || permissionStatus == .restricted
        isAvailable = speechRecognizer?.isAvailable == true && !micDenied && !speechDenied
    }

    @discardableResult
    func requestPermissions() async -> SpeechInputPermissionStatus {
        let speechStatus = await authorizationProvider.requestSpeechAuthorization()
        permissionStatus = mapSpeechStatus(speechStatus)

        if authorizationProvider.recordPermission() == .undetermined {
            _ = await authorizationProvider.requestRecordPermission()
        }

        refreshAvailability()
        return permissionStatus
    }

    func startRecording() async throws {
        guard !isRecording else { throw SpeechInputError.alreadyRecording }
        guard speechRecognizer?.isAvailable == true else {
            throw SpeechInputError.recognizerUnavailable
        }

        if permissionStatus == .notDetermined {
            _ = await requestPermissions()
        }
        refreshAvailability()

        guard permissionStatus == .authorized else {
            throw SpeechInputError.permissionDenied
        }
        guard authorizationProvider.recordPermission() == .granted else {
            throw SpeechInputError.permissionDenied
        }

        liveTranscript = ""
        try prepareAudioSession()
        try startRecognitionSession()
        isRecording = true
    }

    func stopRecording() -> String {
        guard isRecording else { return liveTranscript }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancelRecording() {
        _ = stopRecording()
        liveTranscript = ""
    }

    // MARK: - Private

    private func mapSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> SpeechInputPermissionStatus {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    private func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognitionSession() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw SpeechInputError.audioEngineFailure
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.liveTranscript = result.bestTranscription.formattedString
                }
            }
            if error != nil {
                Task { @MainActor in
                    self.isRecording = false
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SpeechInputError.audioEngineFailure
        }
    }
}
