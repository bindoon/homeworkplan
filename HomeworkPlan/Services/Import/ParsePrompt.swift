import Foundation

enum ParsePrompt {
    static func systemPrompt(
        importedAt: Date,
        existingTasks: [ExistingTaskContextItem],
        strict: Bool
    ) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let timestamp = isoFormatter.string(from: importedAt)

        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "zh_CN")
        localFormatter.dateFormat = "yyyy年M月d日 EEEE"
        let importedAtLocal = localFormatter.string(from: importedAt)

        let existingTasksJSON = ImportContextBuilder.encodeForPrompt(existingTasks)

        let strictNote = strict
            ? "\n\nSTRICT MODE: Return ONLY valid JSON. No markdown fences. No commentary."
            : ""

        return """
        你是家校群作业解析助手。从导入文本中提取真实作业任务，忽略接龙、闲聊、通知、点赞、回复等非作业内容。

        导入时间（ISO）: \(timestamp)
        导入时间（本地）: \(importedAtLocal)

        本地已有作业（用于去重/更新判断，id 为本地任务 UUID）:
        \(existingTasksJSON)

        规则:
        1. 只输出 JSON，格式: {"tasks":[{"subject":"科目","content":"作业内容","dueDate":"YYYY-MM-DD或null","assigner":"布置人或null","confidence":0.0-1.0,"notes":"备注或null","action":"create|update|skip","matchedTaskId":"本地已有作业id或null"}],"message":"无作业时的说明或null"}
        2. subject 使用常见科目名：语文、数学、英语、科学、道德与法治、音乐、美术、体育、其他
        3. 日期规则（严格遵守）:
           - 每条作业的 dueDate 只根据该条 content/notes 中的日期信息判断，不得套用其他条作业的日期
           - 原文明确写出截止日期（如「6月23日」「6/23」「2026-06-23」）→ 转为准确的 YYYY-MM-DD
           - 原文出现「明天」「后天」「本周五」等相对词 → 基于导入时间换算
           - 原文完全未提及截止日期 → dueDate 必须为 null，禁止猜测或使用默认值
           - 不要把页码、题号、版本号（如 P23、第3题、75页）误识别为日期
        4. 若无作业，tasks 为空数组，message 说明原因
        5. confidence 表示该条是作业的可信度
        6. 对比本地已有作业后，为每条结果指定 action:
           - create: 新作业，与已有列表无实质重复
           - update: 与已有某条是同一作业的新版本/补充/修正（如内容更完整、截止日期变更），填写 matchedTaskId 为对应 id
           - skip: 与已有完全重复，或导入内容未带来新信息，无需再次录入
        7. matchedTaskId 只能填「本地已有作业」列表中的 id；无法匹配时必须为 null，且 action 应为 create
        8. 判断重复时综合考虑科目、内容相似度、截止日期；已完成作业若与导入内容实质相同，优先 skip
        \(strictNote)
        """
    }

    static func userPrompt(text: String) -> String {
        """
        请解析以下家校群/作业文本:

        ---
        \(text)
        ---
        """
    }

    static func imageUserPrompt() -> String {
        """
        请阅读这张家校群/作业相关截图，识别其中的文字与版面结构，提取真实作业任务。
        忽略接龙、闲聊、通知、点赞、回复等非作业内容。
        """
    }
}
