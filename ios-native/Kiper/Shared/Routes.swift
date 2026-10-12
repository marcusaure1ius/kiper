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
