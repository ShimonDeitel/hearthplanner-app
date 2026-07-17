import Foundation
import StoreKit

/// StoreKit 2 manager for the single Hearth Pro monthly subscription.
/// Free tier: one kid, no exports. Pro: unlimited kids plus PDF and CSV exports.
@MainActor
final class StoreManager: ObservableObject {
    static let proProductID = "hearth_pro_monthly"

    @Published private(set) var isPro: Bool = false
    @Published private(set) var proProduct: Product?
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // UI-test hook so tests can exercise Pro-gated screens offline.
        if ProcessInfo.processInfo.arguments.contains("--uitest-pro") {
            isPro = true
        }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            lastError = "Could not load products."
        }
    }

    func refreshEntitlements() async {
        if ProcessInfo.processInfo.arguments.contains("--uitest-pro") {
            isPro = true
            return
        }
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
    }

    func purchasePro() async {
        guard let product = proProduct else {
            await loadProducts()
            guard proProduct != nil else {
                lastError = "Hearth Pro is unavailable right now."
                return
            }
            await purchasePro()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase did not complete."
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Restore did not complete."
        }
        await refreshEntitlements()
    }

    /// Free tier allows exactly one kid.
    func canAddKid(currentCount: Int) -> Bool {
        isPro || currentCount < 1
    }
}
