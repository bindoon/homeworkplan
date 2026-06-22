import SwiftUI

struct TaskRowView: View {
    let task: HomeworkTask
    var showCompletedStyle: Bool = false
    let onToggleComplete: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("task-complete-toggle")

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    if let subject = task.subject {
                        Text("\(subject.emoji) \(subject.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(task.content)
                        .font(.body)
                        .lineLimit(2)
                        .strikethrough(showCompletedStyle && task.isCompleted)
                        .foregroundStyle(showCompletedStyle && task.isCompleted ? .secondary : .primary)
                    Text(formattedDueDate)
                        .font(.subheadline)
                        .foregroundStyle(dueDateColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: task.dueDate)
    }

    private var dueDateColor: Color {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: task.dueDate)
        if due < today && !task.isCompleted {
            return .red
        }
        if calendar.isDateInToday(task.dueDate) {
            return .orange
        }
        return .secondary
    }
}

#Preview {
    TaskRowView(
        task: HomeworkTask(subject: nil, content: "背诵古诗", dueDate: Date()),
        onToggleComplete: {},
        onTap: {}
    )
}
