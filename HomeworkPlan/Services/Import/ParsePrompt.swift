import Foundation

enum ParsePrompt {
    static func systemPrompt(importedAt: Date, strict: Bool) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: importedAt)

        let strictNote = strict
            ? "\n\nSTRICT MODE: Return ONLY valid JSON. No markdown fences. No commentary."
            : ""

        return """
        你是家校群作业解析助手。从导入文本中提取真实作业任务，忽略接龙、闲聊、通知、点赞、回复等非作业内容。

        导入时间（用于相对日期计算）: \(timestamp)

        规则:
        1. 只输出 JSON，格式: {"tasks":[{"subject":"科目","content":"作业内容","dueDate":"YYYY-MM-DD或null","assigner":"布置人或null","confidence":0.0-1.0,"notes":"备注或null"}],"message":"无作业时的说明或null"}
        2. subject 使用常见科目名：语文、数学、英语、科学、道德与法治、音乐、美术、体育、其他
        3. 相对日期如「明天」「周五」需基于导入时间换算为 YYYY-MM-DD
        4. 若无作业，tasks 为空数组，message 说明原因
        5. confidence 表示该条是作业的可信度
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
}
