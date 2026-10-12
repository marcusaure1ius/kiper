import SwiftUI

enum Route: Hashable {
    case list
    case detail(Subscription.ID)
}

extension View {
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .list: SubscriptionsListScreen()
            case .detail(let id): SubscriptionDetailScreen(subscriptionId: id)
            }
        }
    }
}

/// Cross-screen navigation state (tab + home stack), so a notification tap can
/// open a subscription from anywhere.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .home
    var homePath: [Route] = []

    func openSubscription(_ id: String) {
        tab = .home
        homePath = [.detail(id)]
    }
}
