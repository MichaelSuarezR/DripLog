import Foundation
import Combine

@MainActor
final class ProfilePhotoStore: ObservableObject {
    @Published private(set) var url: URL?

    private let userID: UUID
    private var didLoad = false
    private var isLoading = false
    private var service: AuthServicing?

    init(userID: UUID) {
        self.userID = userID
    }

    func loadIfNeeded(force: Bool = false) async {
        guard force || !didLoad, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            url = try await getService().fetchProfilePhotoURL(for: userID)
            didLoad = true

            if let url {
                Task {
                    await ImageCache.shared.prefetchAndPin(url: url)
                }
            }
        } catch {
            url = nil
            didLoad = true
        }
    }

    private func getService() throws -> AuthServicing {
        if let service {
            return service
        }

        let createdService = try SupabaseAuthService()
        service = createdService
        return createdService
    }
}
