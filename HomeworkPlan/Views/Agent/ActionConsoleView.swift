import PhotosUI
import SwiftUI

struct ActionConsoleView: View {
    var onVisitHome: () -> Void = {}

    @Environment(\.appDependencies) private var dependencies
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: ActionConsoleViewModel?
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var zoomedImageItem: ImagePreviewItem?
    @FocusState private var inputFocused: Bool

    private var pageBackground: Color {
        Color(.systemBackground)
    }

    private var composerSurface: Color {
        Color(.secondarySystemBackground)
    }

    private var controlFill: Color {
        Color(.tertiarySystemFill)
    }

    private func sendButtonFill(canSend: Bool) -> Color {
        guard canSend else { return Color(.systemGray3) }
        return colorScheme == .dark ? Color.white : Color.black
    }

    private func sendButtonIconColor(canSend: Bool) -> Color {
        guard canSend else { return Color.white }
        return colorScheme == .dark ? Color.black : Color.white
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let viewModel {
                conversationList(viewModel: viewModel)
                composerCard(viewModel: viewModel)
            } else {
                ProgressView("加载中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(pageBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if viewModel == nil, let orchestrator = dependencies?.agentOrchestrator {
                viewModel = ActionConsoleViewModel(
                    orchestrator: orchestrator,
                    speechService: SpeechInputService()
                )
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let viewModel {
                    await viewModel.attachImage(image)
                }
                selectedPhotoItem = nil
            }
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .fullScreenCover(item: $zoomedImageItem) { item in
            ZoomableImagePreview(image: item.image)
        }
        .accessibilityIdentifier("action-console-view")
    }

    private var topBar: some View {
        HStack {
            Button(action: onVisitHome) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("返回")
            .accessibilityIdentifier("action-console-back")

            Spacer()

            Button("清空") {
                viewModel?.clearConversation()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .disabled(viewModel?.turns.isEmpty ?? true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func conversationList(viewModel: ActionConsoleViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.turns.isEmpty {
                        emptyState
                    }

                    ForEach(viewModel.turns) { turn in
                        conversationRow(turn: turn, viewModel: viewModel)
                            .id(turn.id)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.turns.count) { _, _ in
                scrollToBottom(proxy: proxy, viewModel: viewModel)
            }
            .onChange(of: viewModel.turns.map(\.text)) { _, _ in
                scrollToBottom(proxy: proxy, viewModel: viewModel)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, viewModel: ActionConsoleViewModel) {
        if let last = viewModel.turns.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func conversationRow(turn: ConversationTurn, viewModel: ActionConsoleViewModel) -> some View {
        if turn.role == .user {
            HStack {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 8) {
                    if let image = turn.attachedImage {
                        TappableMessageImage(
                            image: image,
                            maxWidth: 200,
                            maxHeight: 160
                        ) {
                            zoomedImageItem = ImagePreviewItem(image: image)
                        }
                    }
                    if !turn.text.isEmpty, turn.text != "[截图]" {
                        Text(turn.text)
                            .padding(12)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if turn.text == "[截图]" && turn.attachedImage == nil {
                        Text(turn.text)
                            .padding(12)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        } else if let proposal = turn.proposal {
            AgentProposalCard(
                proposal: proposal,
                onConfirm: { viewModel.confirmProposal(id: proposal.id) },
                onReject: { viewModel.rejectProposal(id: proposal.id) }
            )
        } else {
            HStack(alignment: .top) {
                AgentMarkdownText(text: turn.text, isStreaming: turn.isStreaming)
                    .padding(12)
                    .background(composerSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer(minLength: 48)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("描述作业或指令")
                .font(.headline)
            Text("可语音、贴图，或直接输入文字")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 6) {
                Text("试试：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("「明天交数学练习册 P15」")
                Text("「加一门科学」")
                Text("「每天练字」")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    @ViewBuilder
    private func composerCard(viewModel: ActionConsoleViewModel) -> some View {
        @Bindable var speechService = viewModel.speechService

        VStack(spacing: 8) {
            if let hint = viewModel.speechUnavailableMessage {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isRecordingSpeech {
                    recordingControlBar(viewModel: viewModel, liveTranscript: speechService.liveTranscript)
                }

                if let image = viewModel.attachedImage {
                    attachmentChip(image: image, viewModel: viewModel)
                }

                ZStack(alignment: .topLeading) {
                    if viewModel.inputText.isEmpty, !viewModel.isRecordingSpeech {
                        Text("描述作业或指令…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }

                    TextField("", text: Bindable(viewModel).inputText, axis: .vertical)
                        .lineLimit(1 ... 6)
                        .focused($inputFocused)
                        .accessibilityIdentifier("action-console-input")
                }
                .frame(minHeight: 44, alignment: .topLeading)

                HStack(spacing: 12) {
                    attachmentMenu(viewModel: viewModel)

                    modelBadge

                    Spacer(minLength: 8)

                    micButton(viewModel: viewModel)

                    if viewModel.isProcessing {
                        stopButton(viewModel: viewModel)
                    } else if viewModel.isRecordingSpeech {
                        EmptyView()
                    } else {
                        sendButton(viewModel: viewModel)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(composerSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func recordingControlBar(viewModel: ActionConsoleViewModel, liveTranscript: String) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.cancelSpeechRecording()
            } label: {
                Label("取消", systemImage: "xmark")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
            }
            .accessibilityIdentifier("action-console-cancel-recording")

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .foregroundStyle(.red)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text(liveTranscript.isEmpty ? "正在聆听…" : liveTranscript)
                    .lineLimit(2)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button {
                Task { await viewModel.endSpeechRecording(sendImmediately: false) }
            } label: {
                Text("完成")
                    .font(.subheadline.weight(.medium))
            }
            .accessibilityIdentifier("action-console-finish-recording")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func attachmentChip(image: UIImage, viewModel: ActionConsoleViewModel) -> some View {
        HStack(spacing: 10) {
            Button {
                zoomedImageItem = ImagePreviewItem(image: image)
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if viewModel.isExtractingOCR {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("识别截图文字…")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("已附加截图")
                        .font(.caption.weight(.medium))
                    Text("发送后将导入作业")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                viewModel.removeAttachedImage()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .disabled(viewModel.isExtractingOCR)
        }
        .padding(10)
        .background(controlFill.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func attachmentMenu(viewModel: ActionConsoleViewModel) -> some View {
        Menu {
            Button {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    isPhotoPickerPresented = true
                }
            } label: {
                Label("从相册选择", systemImage: "photo")
            }
            .accessibilityIdentifier("action-console-photo-picker")

            Button {
                Task { await viewModel.pasteImageFromClipboard() }
            } label: {
                Label("粘贴截图", systemImage: "doc.on.clipboard")
            }
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(Circle().fill(controlFill))
        }
        .accessibilityIdentifier("action-console-attach-menu")
    }

    private var modelBadge: some View {
        Text(AppSecrets.llmModel)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(controlFill)
            )
            .lineLimit(1)
    }

    @ViewBuilder
    private func micButton(viewModel: ActionConsoleViewModel) -> some View {
        let isDisabled = !viewModel.isSpeechAvailable || viewModel.isProcessing

        Button {
            guard viewModel.isSpeechAvailable, !viewModel.isProcessing else { return }
            Task {
                if viewModel.isRecordingSpeech {
                    await viewModel.endSpeechRecording()
                } else {
                    await viewModel.beginSpeechRecording()
                }
            }
        } label: {
            Image(systemName: viewModel.isRecordingSpeech ? "mic.fill" : "mic")
                .font(.body)
                .foregroundStyle(viewModel.isRecordingSpeech ? .red : .primary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(viewModel.isRecordingSpeech ? Color.red.opacity(0.12) : controlFill)
                )
        }
        .accessibilityIdentifier("action-console-mic")
        .opacity(isDisabled && !viewModel.isRecordingSpeech ? 0.35 : 1)
        .disabled(isDisabled && !viewModel.isRecordingSpeech)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !viewModel.isRecordingSpeech, viewModel.isSpeechAvailable else { return }
                    Task { await viewModel.beginSpeechRecording() }
                }
                .onEnded { _ in
                    Task { await viewModel.endSpeechRecording() }
                }
        )
    }

    @ViewBuilder
    private func sendButton(viewModel: ActionConsoleViewModel) -> some View {
        Button {
            viewModel.sendMessage()
        } label: {
            ZStack {
                Circle()
                    .fill(sendButtonFill(canSend: viewModel.canSend))
                    .frame(width: 34, height: 34)
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(sendButtonIconColor(canSend: viewModel.canSend))
            }
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSend)
        .accessibilityIdentifier("action-console-send")
    }

    @ViewBuilder
    private func stopButton(viewModel: ActionConsoleViewModel) -> some View {
        Button {
            viewModel.stopProcessing()
        } label: {
            Image(systemName: "stop.fill")
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.red))
        }
        .accessibilityIdentifier("action-console-stop")
    }
}

private struct ImagePreviewItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    ActionConsoleView()
}
