import PhotosUI
import SwiftUI

struct ActionConsoleView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ActionConsoleViewModel?
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let viewModel {
                    conversationList(viewModel: viewModel)
                    attachmentPreview(viewModel: viewModel)
                    inputBar(viewModel: viewModel)
                } else {
                    ProgressView("加载中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("操作")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") {
                        viewModel?.clearConversation()
                    }
                    .disabled(viewModel?.turns.isEmpty ?? true)
                }
            }
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
        }
        .accessibilityIdentifier("action-console-view")
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

                    if viewModel.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("思考中…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.turns.count) { _, _ in
                if let last = viewModel.turns.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
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
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180, maxHeight: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if !turn.text.isEmpty {
                        Text(turn.text)
                            .padding(12)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            HStack {
                Text(turn.text)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 48)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("输入、贴图或语音描述作业")
                .font(.headline)
            Text("可粘贴截图、按住麦克风说话，或直接输入文字")
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
    private func attachmentPreview(viewModel: ActionConsoleViewModel) -> some View {
        if viewModel.attachedImage != nil || viewModel.isExtractingOCR {
            HStack(spacing: 12) {
                if let image = viewModel.attachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if viewModel.isExtractingOCR {
                    ProgressView()
                    Text("识别截图文字…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("已附加截图，发送后将导入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
        }
    }

    @ViewBuilder
    private func inputBar(viewModel: ActionConsoleViewModel) -> some View {
        VStack(spacing: 8) {
            if let hint = viewModel.speechUnavailableMessage {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.isRecordingSpeech {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.red)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    Text("正在聆听…松开发送")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title3)
                }
                .accessibilityIdentifier("action-console-attach-photo")

                Button {
                    Task { await viewModel.pasteImageFromClipboard() }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                }
                .accessibilityIdentifier("action-console-paste-image")

                micButton(viewModel: viewModel)

                TextField("输入消息…", text: Bindable(viewModel).inputText, axis: .vertical)
                    .lineLimit(1 ... 5)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("action-console-input")

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.canSend)
                .accessibilityIdentifier("action-console-send")
            }
        }
        .padding()
        .background(.bar)
    }

    @ViewBuilder
    private func micButton(viewModel: ActionConsoleViewModel) -> some View {
        let isDisabled = !viewModel.isSpeechAvailable || viewModel.isProcessing

        Image(systemName: viewModel.isRecordingSpeech ? "mic.fill" : "mic")
            .font(.title3)
            .foregroundStyle(viewModel.isRecordingSpeech ? .red : (isDisabled ? .secondary : .primary))
            .padding(6)
            .background(
                Circle()
                    .fill(viewModel.isRecordingSpeech ? Color.red.opacity(0.15) : Color.clear)
            )
            .accessibilityIdentifier("action-console-mic")
            .opacity(isDisabled && !viewModel.isRecordingSpeech ? 0.4 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !viewModel.isRecordingSpeech else { return }
                        Task { await viewModel.beginSpeechRecording() }
                    }
                    .onEnded { _ in
                        Task { await viewModel.endSpeechRecording() }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        guard viewModel.isSpeechAvailable, !viewModel.isProcessing else { return }
                        Task {
                            if viewModel.isRecordingSpeech {
                                await viewModel.endSpeechRecording()
                            } else {
                                await viewModel.beginSpeechRecording()
                            }
                        }
                    }
            )
    }
}

#Preview {
    ActionConsoleView()
}
