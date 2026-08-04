# 生存计划 (Survival Plan)

帮助你在职业空窗期管理财务的 iOS 应用。知道钱在哪，日子就能过下去。

## 功能

- **看板**：每日操作台——记账、今日预算、风险等级、资金耗尽日、已失业天数
- **预算**：月度分析台——分类健康度、月底预测、趋势曲线
- **模拟器**：找到工作 / 削减开支 / 卖车 / 借款等场景模拟 + 目标反推（积蓄能撑多久、还差多少、怎么补）
- **圈子**：失业互助社区——树洞倾诉、找工作信息、运动/学习打卡、点赞评论

## 技术栈

- SwiftUI + SwiftData（iOS 17+）
- 圈子后端：FastAPI + SQLite（[survivalplan-server](https://github.com/raofq/survivalplan-server)）

## 变现模式

Freemium + 一次性买断（Pro）。付费墙原则：免费 = 救命功能（记账/预算/模拟核心/圈子基础参与），Pro = 提升功能（高级模拟场景、求职加成、iCloud 同步、完整数据导出）。

## 开发

```bash
# 构建（模拟器）
xcodebuild -project 生存计划.xcodeproj -scheme 生存计划 \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## 反馈

通过 [Issues](https://github.com/raofq/survivalplan/issues) 提交反馈与建议。

## License

Private（暂未开源）。
