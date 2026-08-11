import Foundation
import StoreKit

// MARK: - 内购管理器（StoreKit 2）
/// 管理 Pro 买断产品的购买/恢复/状态。
/// 产品未在 App Store Connect 配置时：购买静默失败、UI 显示「即将上线」。
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    /// 产品 ID（与 App Store Connect 保持一致；bundle ID 上架前换真实值后需同步）
    static let proProductID = "survivalplan.pro"

    @Published private(set) var product: Product?
    @Published private(set) var isPurchased = false
    @Published var showPaywall = false
    /// 最近一次购买/恢复的错误信息（UI 展示用，便于诊断沙盒/产品问题）
    @Published var lastError: String?

    /// 开发期开关：无需真实内购即可预览 Pro 解锁效果（上线前必须关掉）
    static var debugUnlockPro = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result, transaction.productID == Self.proProductID {
                    await self?.apply(transaction: transaction)
                }
            }
        }
        Task { await refresh() }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// 拉取产品信息 + 恢复购买状态
    func refresh() async {
        if let product = try? await Product.products(for: [Self.proProductID]).first {
            self.product = product
        }
        await refreshEntitlements()
    }

    /// 查询当前拥有的交易（恢复购买）
    func refreshEntitlements() async {
        var purchased = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.proProductID {
                purchased = true
            }
        }
        isPurchased = purchased
        syncFlag()
    }

    /// 发起购买
    func purchase() async {
        guard let product else {
            lastError = L("产品不可用，请稍后重试")
            return
        }
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await apply(transaction: transaction)
                    await transaction.finish()
                }
            case .userCancelled:
                break
            case .pending:
                lastError = L("购买待处理，请稍后查看")
            @unknown default:
                break
            }
        } catch {
            lastError = L("购买失败：") + error.localizedDescription
        }
    }

    /// 恢复购买（换设备/重装）
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func apply(transaction: Transaction) async {
        if transaction.productID == Self.proProductID, transaction.revocationDate == nil {
            isPurchased = true
        }
        syncFlag()
    }

    /// 同步到 FeatureFlags（全局付费墙开关）
    private func syncFlag() {
        ProFeatures.isPro = isPurchased || Self.debugUnlockPro
    }
}
