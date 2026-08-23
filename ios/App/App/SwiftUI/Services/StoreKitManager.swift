import Foundation
import StoreKit
import Combine

@available(iOS 15.0, *)
@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()
    
    @Published public var isProUnlocked: Bool = true // Enabled for dev testing
    @Published public var availableProducts: [Product] = []
    @Published public var isPurchasing: Bool = false
    
    public let proProductId = "app.kraftwuerfel.pro.monthly"
    
    private init() {
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    public func fetchProducts() async {
        do {
            self.availableProducts = try await Product.products(for: [proProductId])
        } catch {
            print("StoreKit fetch error: \(error)")
        }
    }
    
    public func purchasePro() async -> Bool {
        guard let product = availableProducts.first(where: { $0.id == proProductId }) else {
            // For simulator / preview fallback
            self.isProUnlocked = true
            return true
        }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    self.isProUnlocked = true
                    return true
                case .unverified:
                    return false
                }
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }
    
    public func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == proProductId {
                    self.isProUnlocked = true
                    return
                }
            }
        }
    }
}
