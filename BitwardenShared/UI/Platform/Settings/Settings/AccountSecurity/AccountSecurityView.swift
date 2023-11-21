import SwiftUI

// MARK: - AccountSecurityView

/// A view that allows the user to update their account security settings.
///
struct AccountSecurityView: View {
    // MARK: Properties

    /// The store used to render the view.
    @ObservedObject var store: Store<AccountSecurityState, AccountSecurityAction, AccountSecurityEffect>

    // MARK: View

    var body: some View {
        VStack(spacing: 20) {
            approveLoginRequestsSection

            unlockOptionsSection

            sessionTimeoutSection

            otherSection
        }
        .scrollView()
        .navigationBar(title: Localizations.accountSecurity, titleDisplayMode: .inline)
        .background(Asset.Colors.backgroundSecondary.swiftUIColor.ignoresSafeArea())
    }

    // MARK: Private views

    /// The approve login requests section.
    private var approveLoginRequestsSection: some View {
        VStack(alignment: .leading) {
            SectionHeaderView(Localizations.approveLoginRequests)

            ToggleView(
                isOn: store.binding(
                    get: \.isApproveLoginRequestsToggleOn,
                    send: AccountSecurityAction.toggleApproveLoginRequestsToggle
                ),
                description: Localizations.useThisDeviceToApproveLoginRequestsMadeFromOtherDevices
            )

            if store.state.isApproveLoginRequestsToggleOn {
                SettingsListItem(
                    Localizations.pendingLogInRequests,
                    hasDivider: false
                ) {}
                    .cornerRadius(10)
            }
        }
    }

    /// The other section.
    private var otherSection: some View {
        VStack(alignment: .leading) {
            SectionHeaderView(Localizations.other)

            VStack(spacing: 0) {
                SettingsListItem(Localizations.accountFingerprintPhrase) {}

                SettingsListItem(Localizations.twoStepLogin) {} trailingContent: {
                    Image(asset: Asset.Images.externalLink)
                        .resizable()
                        .frame(width: 22, height: 22)
                }

                SettingsListItem(Localizations.lockNow) {
                    Task {
                        await store.perform(.lockVault)
                    }
                }

                SettingsListItem(
                    Localizations.logOut,
                    hasDivider: false
                ) {
                    store.send(.logout)
                }
            }
            .cornerRadius(10)
        }
    }

    /// The session timeout section.
    private var sessionTimeoutSection: some View {
        VStack(alignment: .leading) {
            SectionHeaderView(Localizations.sessionTimeout)

            VStack(spacing: 0) {
                SettingsListItem(
                    Localizations.sessionTimeout
                ) {} trailingContent: {
                    Text(Localizations.fifteenMinutes)
                }

                SettingsListItem(
                    Localizations.sessionTimeoutAction,
                    hasDivider: false
                ) {} trailingContent: {
                    Text(Localizations.lock)
                }
            }
            .cornerRadius(10)
        }
        .padding(.top, 8)
    }

    /// The unlock options section.
    private var unlockOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(Localizations.unlockOptions)

            VStack(spacing: 24) {
                if store.state.biometricAuthenticationType == .touchID {
                    ToggleView(
                        isOn: store.binding(
                            get: \.isUnlockWithTouchIDToggleOn,
                            send: AccountSecurityAction.toggleUnlockWithTouchID
                        ),
                        description: Localizations.unlockWith(Localizations.touchID)
                    )
                }

                if store.state.biometricAuthenticationType == .faceID {
                    ToggleView(
                        isOn: store.binding(
                            get: \.isUnlockWithFaceIDOn,
                            send: AccountSecurityAction.toggleUnlockWithFaceID
                        ),
                        description: Localizations.unlockWith(Localizations.faceID)
                    )
                }

                ToggleView(
                    isOn: store.binding(
                        get: \.isUnlockWithPINCodeOn,
                        send: AccountSecurityAction.toggleUnlockWithPINCode
                    ),
                    description: Localizations.unlockWithPIN
                )
            }
        }
    }
}

// MARK: - Previews

struct AccountSecurityView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountSecurityView(
                store: Store(processor: StateProcessor(state: AccountSecurityState()))
            )
        }
    }
}
