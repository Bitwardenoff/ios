// MARK: - VaultListEffect

/// Effects that can be processed by a `VaultListProcessor`.
enum VaultListEffect {
    /// The vault list appeared on screen.
    case appeared

    /// Refresh the vault list's data.
    case refresh
}
