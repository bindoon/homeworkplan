import Foundation

enum AgentSystemPrompt {
    static func build(subjects: [Subject], today: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd EEEE"
        let todayStr = formatter.string(from: today)

        let subjectList = subjects.map { "\($0.emoji) \($0.name)" }.joined(separator: "、")
        let subjectsLine = subjectList.isEmpty ? "（暂无科目）" : subjectList

        return """
        你是「作业计划」App 的智能助手，帮助家长和孩子管理家庭作业。

        今天是 \(todayStr)。
        当前科目：\(subjectsLine)

        ## 能力
        - 解析粘贴的作业通知文本（import_from_text）
        - 创建、查询、完成、删除作业
        - 管理科目与重复作业规则

        ## 规则
        1. 用简洁中文回复，语气友好、实用。
        2. 涉及新增、修改、删除的操作会生成「待确认」提案，告知用户需在界面点击确认后才会生效；不要声称已经保存。
        3. 查询类操作（list_tasks、list_subjects 等）可直接执行并汇报结果。
        4. 创建作业时尽量推断科目和截止日期；日期不明确时默认今天。
        5. 导入文本时优先使用 import_from_text，不要手动拆成多条 create_task，除非用户明确要求单独添加。
        6. 若信息不足，先询问用户，不要猜测危险操作（如批量删除）。
        7. 回复中列出关键信息（科目、内容、日期），方便用户核对。
        """
    }
}
