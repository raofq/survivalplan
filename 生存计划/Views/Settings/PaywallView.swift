import SwiftUI
import StoreKit

// MARK: - Pro 购买页（Paywall）
struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 顶部皇冠
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                    .padding(.top, 30)

                Text(L("升级 Survival Pro"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(L("一次性买断，永久解锁全部高级功能"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // 功能清单
                VStack(alignment: .leading, spacing: 12) {
                    featureRow("模拟器高级场景", "卖车 / 停购物 / 停补课 / 借款")
                    featureRow("试用期精细模拟", "试用期月薪与时长")
                    featureRow("目标反推完整建议", "找工作的具体月薪目标")
                    featureRow("iCloud 同步", "记账与设置跨设备")
                    featureRow("完整数据导出", "全部模块 + 图片")
                    featureRow("云端推送提醒", "岗位订阅 / 圈子互动")
                }
                .padding(16)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))

                Spacer()

                // 价格 + 购买
                if let product = store.product {
                    Button {
                        Task { await store.purchase() }
                    } label: {
                        Text("解锁 Pro — \(product.displayPrice)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Text(L("内购即将上线，敬请期待"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground), in: .capsule)
                }

                Button(L("恢复购买")) {
                    Task { await store.restore() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(L("付款将通过与 Apple 关联的 iTunes 账户收取。确认购买前，此 App 将显示价格和条款。"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding()
            .navigationTitle("Survival Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("关闭")) { dismiss() }
                }
            }
        }
    }

    private func featureRow(_ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(title))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(L(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
