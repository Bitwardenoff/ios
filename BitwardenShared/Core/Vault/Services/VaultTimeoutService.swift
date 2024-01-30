import Combine
import Foundation

// MARK: - VaultTimeoutServiceError

/// The errors thrown from a `VaultTimeoutService`.
///
enum VaultTimeoutServiceError: Error {
    /// There are no known accounts.
    case noAccountFound
}

// MARK: - VaultTimeoutService

/// A protocol for handling vault access.
///
protocol VaultTimeoutService: AnyObject {
    // MARK: Methods

    /// Checks the locked status of a user vault by user id
    ///  - Parameter userId: The userId of the account
    ///  - Returns: A bool, true if locked, false if unlocked.
    ///
    func isLocked(userId: String) throws -> Bool

    /// Locks the user's vault
    ///
    /// - Parameter userId: The userId of the account to lock.
    ///     Defaults to the active account if nil
    ///
    func lockVault(userId: String?) async

    /// Removes an account id.
    ///
    /// - Parameter userId: The user's ID.
    ///
    func remove(userId: String?) async

    /// Sets the last active time within the app.
    ///
    /// - Parameter userId: The user ID associated with the last active time within the app.
    ///
    func setLastActiveTime(userId: String) async throws

    /// Sets the session timeout date upon the app being backgrounded.
    ///
    /// - Parameters:
    ///   - value: The timeout value.
    ///   - userId: The user's ID.
    ///
    func setVaultTimeout(value: SessionTimeoutValue, userId: String?) async throws

    /// Whether a session timeout should occur.
    ///
    /// - Returns: Whether a session timeout should occur.
    ///
    func shouldSessionTimeout(userId: String) async throws -> Bool

    /// Unlocks the user's vault
    ///
    /// - Parameter userId: The userId of the account to unlock.
    ///     Defaults to the active account if nil
    ///
    func unlockVault(userId: String?) async
}

// MARK: - DefaultVaultTimeoutService

class DefaultVaultTimeoutService: VaultTimeoutService {
    // MARK: Properties

    /// A subject containing the active account id.
    var activeAccountIdSubject = CurrentValueSubject<String?, Never>(nil)

    /// The state service used by this Default Service.
    private var stateService: StateService

    /// The store of locked status for known accounts
    var timeoutStore = [String: Bool]()

    /// A String to track the last known active account id.
    var lastKnownActiveAccountId: String?

    // MARK: Initialization

    /// Creates a new `DefaultVaultTimeoutService`.
    ///
    /// - Parameter stateService: The StateService used by DefaultVaultTimeoutService.
    ///
    init(stateService: StateService) {
        self.stateService = stateService
    }

    // MARK: Methods

    func isLocked(userId: String) throws -> Bool {
        guard let isLocked = timeoutStore[userId] else {
            throw VaultTimeoutServiceError.noAccountFound
        }
        return isLocked
    }

    func lockVault(userId: String?) async {
        guard let id = try? await stateService.getAccountIdOrActiveId(userId: userId) else { return }
        timeoutStore[id] = true
    }

    func remove(userId: String?) async {
        guard let id = try? await stateService.getAccountIdOrActiveId(userId: userId) else { return }
        timeoutStore = timeoutStore.filter { $0.key != id }
    }

    func setLastActiveTime(userId: String) async throws {
        try await stateService.setLastActiveTime(Date(), userId: userId)
    }

    func setVaultTimeout(value: SessionTimeoutValue, userId: String?) async throws {
        try await stateService.setVaultTimeout(value: value, userId: userId)
    }

    func shouldSessionTimeout(userId: String) async throws -> Bool {
        guard let lastActiveTime = try await stateService.getLastActiveTime(userId: userId) else { return true }
        let vaultTimeout = try await stateService.getVaultTimeout(userId: userId)

        if vaultTimeout == .onAppRestart { return true }
        if vaultTimeout == .never { return false }

        if Date().timeIntervalSince(lastActiveTime) >= TimeInterval(vaultTimeout.rawValue) {
            return true
        }
        return false
    }

    func unlockVault(userId: String?) async {
        guard let id = try? await stateService.getAccountIdOrActiveId(userId: userId) else { return }
        var updatedStore = timeoutStore.mapValues { _ in true }
        updatedStore[id] = false
        timeoutStore = updatedStore
    }
}
