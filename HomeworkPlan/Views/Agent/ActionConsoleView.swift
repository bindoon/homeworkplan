import SwiftUI

struct ActionConsoleView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel: ActionConsoleViewModel?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let viewModel {
                    conversationList(viewModel: viewModel)
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
                    viewModel = ActionConsoleViewModel(orchestrator: orchestrator)
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
                Text(turn.text)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
            Text("输入作业通知或指令")
                .font(.headline)
            Text("例如：「明天数学完成练习册 P10」或粘贴群消息")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    @ViewBuilder
    private func inputBar(viewModel: ActionConsoleViewModel) -> some View {
        HStack(spacing: 8) {
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
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
            .accessibilityIdentifier("action-console-send")
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    ActionConsoleView()
}
