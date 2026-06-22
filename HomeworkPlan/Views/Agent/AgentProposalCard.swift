import SwiftUI

struct AgentProposalCard: View {
    let proposal: AgentProposal
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(statusColor)
                Text(proposal.summary)
                    .font(.headline)
                Spacer()
                statusBadge
            }

            if !proposal.detailLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(proposal.detailLines, id: \.self) { line in
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if proposal.status == .pending {
                HStack(spacing: 12) {
                    Button("确认", action: onConfirm)
                        .buttonStyle(.borderedProminent)
                    Button("取消", role: .cancel, action: onReject)
                        .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("agent-proposal-\(proposal.id.uuidString)")
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch proposal.status {
        case .pending:
            Text("待确认")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .clipShape(Capsule())
        case .confirmed:
            Text("已确认")
                .font(.caption)
                .foregroundStyle(.green)
        case .rejected:
            Text("已取消")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        switch proposal.kind {
        case .createTask, .importCandidates, .createSubject, .createRecurringRule:
            return "plus.circle"
        case .updateSubject, .updateRecurringRule, .toggleTaskComplete, .setRecurringRuleEnabled:
            return "pencil.circle"
        case .deleteSubject, .deleteTask, .deleteRecurringRule:
            return "trash.circle"
        }
    }

    private var statusColor: Color {
        switch proposal.status {
        case .pending: return .orange
        case .confirmed: return .green
        case .rejected: return .secondary
        }
    }
}

#Preview {
    AgentProposalCard(
        proposal: AgentProposal(
            kind: .createTask,
            summary: "创建作业",
            detailLines: ["科目：数学", "内容：练习册 P10", "截止：2026-06-25"],
            payload: .createTask(
                CreateTaskPayload(
                    subjectName: "数学",
                    content: "练习册 P10",
                    notes: "",
                    dueDate: Date()
                )
            )
        ),
        onConfirm: {},
        onReject: {}
    )
    .padding()
}
