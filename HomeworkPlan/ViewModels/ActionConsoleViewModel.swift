import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class ActionConsoleViewModel {
    var inputText: String = ""
    var turns: [ConversationTurn] = []
    var isProcessing: Bool = false
    var errorMessage: String?
    var attachedImage: UIImage?
    var attachedOCRText: String?
    var isExtractingOCR: Bool = false
    var isRecordingSpeech: Bool = false
    var speechUnavailableMessage: String?

    private let orchestrator: AgentOrchestrator
    let speechService: SpeechInputService
    private var sendTask: Task<Void, Never>?

    init(orchestrator: AgentOrchestrator, speechService: SpeechInputService) {
        self.orchestrator = orchestrator
        self.speechService = speechService
        speechService.refreshAvailability()
        updateSpeechAvailabilityMessage()
    }

    var liveSpeechTranscript: String {
        speechService.liveTranscript
    }

    var canSend: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = attachedImage != nil && attachedOCRText != nil
        return (hasText || hasImage) && !isProcessing && !isExtractingOCR && !isRecordingSpeech
    }

    var isSpeechAvailable: Bool {
        speechService.isAvailable
    }

    func sendMessage() {
        sendTask?.cancel()
        sendTask = Task { await performSendMessage() }
    }

    func stopProcessing() {
        guard isProcessing else { return }
        sendTask?.cancel()
        sendTask = nil
        orchestrator.finalizeCancellation()
        syncTurns()
        isProcessing = false
    }

    private func performSendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = buildAttachment()
        guard !text.isEmpty || attachment != nil, !isProcessing else { return }

        inputText = ""
        clearAttachment()
        isProcessing = true
        errorMessage = nil
        defer {
            isProcessing = false
            sendTask = nil
        }

        do {
            try await orchestrator.sendUserMessage(text, attachment: attachment) { [weak self] in
                self?.syncTurns()
            }
            syncTurns()
        } catch is CancellationError {
            orchestrator.finalizeCancellation { [weak self] in
                self?.syncTurns()
            }
            syncTurns()
        } catch {
            errorMessage = error.localizedDescription
            syncTurns()
        }
    }

    func pasteImageFromClipboard() async {
        guard UIPasteboard.general.hasImages,
              let image = UIPasteboard.general.image else {
            errorMessage = "剪贴板中没有图片"
            return
        }
        await attachImage(image)
    }

    func attachImage(_ image: UIImage) async {
        attachedImage = image
        attachedOCRText = nil
        isExtractingOCR = true
        errorMessage = nil
        defer { isExtractingOCR = false }

        do {
            attachedOCRText = try await OCRService.recognizeText(from: image)
        } catch {
            attachedImage = nil
            errorMessage = "截图识别失败：\(error.localizedDescription)"
        }
    }

    func removeAttachedImage() {
        clearAttachment()
    }

    func beginSpeechRecording() async {
        guard speechService.isAvailable else {
            updateSpeechAvailabilityMessage()
            return
        }

        errorMessage = nil
        do {
            try await speechService.startRecording()
            isRecordingSpeech = true
        } catch let error as SpeechInputError {
            isRecordingSpeech = false
            if error == .permissionDenied {
                speechService.refreshAvailability()
                updateSpeechAvailabilityMessage()
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            isRecordingSpeech = false
            errorMessage = error.localizedDescription
        }
    }

    func endSpeechRecording(sendImmediately: Bool = true) async {
        guard isRecordingSpeech else { return }
        let transcript = speechService.stopRecording()
        isRecordingSpeech = false

        guard !transcript.isEmpty else { return }

        if sendImmediately {
            inputText = transcript
            sendMessage()
        } else {
            inputText = transcript
        }
    }

    func cancelSpeechRecording() {
        speechService.cancelRecording()
        isRecordingSpeech = false
    }

    func confirmProposal(id: UUID) {
        do {
            _ = try orchestrator.confirmProposal(id: id)
            errorMessage = nil
            syncTurns()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectProposal(id: UUID) {
        orchestrator.rejectProposal(id: id)
        syncTurns()
    }

    func clearConversation() {
        sendTask?.cancel()
        sendTask = nil
        isProcessing = false
        orchestrator.clearConversation()
        turns = []
        errorMessage = nil
        clearAttachment()
        cancelSpeechRecording()
    }

    private func buildAttachment() -> UserMessageAttachment? {
        guard let image = attachedImage,
              let ocrText = attachedOCRText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !ocrText.isEmpty else {
            return nil
        }
        return UserMessageAttachment(image: image, ocrText: ocrText)
    }

    private func clearAttachment() {
        attachedImage = nil
        attachedOCRText = nil
    }

    private func syncTurns() {
        turns = orchestrator.uiTurns.map { turn in
            ConversationTurn(
                id: turn.id,
                role: turn.role,
                text: turn.text,
                proposal: turn.proposal,
                attachedImage: turn.attachedImage,
                isStreaming: turn.isStreaming
            )
        }
    }

    private func updateSpeechAvailabilityMessage() {
        if speechService.isAvailable {
            speechUnavailableMessage = nil
            return
        }
        switch speechService.permissionStatus {
        case .denied, .restricted:
            speechUnavailableMessage = "语音输入不可用（权限未开启），请使用文字或贴图"
        case .notDetermined:
            speechUnavailableMessage = nil
        case .authorized:
            speechUnavailableMessage = "当前设备不支持中文语音识别"
        }
    }
}
