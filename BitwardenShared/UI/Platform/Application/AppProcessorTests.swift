import Foundation
import XCTest

@testable import BitwardenShared

class AppProcessorTests: BitwardenTestCase {
    // MARK: Properties

    var appModule: MockAppModule!
    var appSettingStore: MockAppSettingsStore!
    var coordinator: MockCoordinator<AppRoute>!
    var errorReporter: MockErrorReporter!
    var notificationCenterService: MockNotificationCenterService!
    var notificationService: MockNotificationService!
    var stateService: MockStateService!
    var subject: AppProcessor!
    var syncService: MockSyncService!
    var timeProvider: MockTimeProvider!
    var vaultTimeoutService: MockVaultTimeoutService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        appModule = MockAppModule()
        appSettingStore = MockAppSettingsStore()
        coordinator = MockCoordinator<AppRoute>()
        errorReporter = MockErrorReporter()
        notificationCenterService = MockNotificationCenterService()
        notificationService = MockNotificationService()
        stateService = MockStateService()
        syncService = MockSyncService()
        timeProvider = MockTimeProvider(.currentTime)
        vaultTimeoutService = MockVaultTimeoutService()

        subject = AppProcessor(
            appModule: appModule,
            services: ServiceContainer.withMocks(
                appSettingsStore: appSettingStore,
                errorReporter: errorReporter,
                notificationService: notificationService,
                stateService: stateService,
                syncService: syncService,
                vaultTimeoutService: vaultTimeoutService
            )
        )
        subject.coordinator = coordinator.asAnyCoordinator()
    }

    override func tearDown() {
        super.tearDown()

        appModule = nil
        appSettingStore = nil
        coordinator = nil
        errorReporter = nil
        notificationCenterService = nil
        notificationService = nil
        stateService = nil
        subject = nil
        syncService = nil
        timeProvider = nil
        vaultTimeoutService = nil
    }

    // MARK: Tests

    /// The user's last active time is updated when the app is backgrounded.
    func test_appBackgrounded_setLastActiveTime() {
        let account: Account = .fixture()
        stateService.activeAccount = account

        vaultTimeoutService.lastActiveTime[account.profile.userId] = .distantPast

        notificationCenterService.didEnterBackgroundSubject.send()
        waitFor(vaultTimeoutService.lastActiveTime[account.profile.userId] != .distantPast)

        let updated = vaultTimeoutService.lastActiveTime[account.profile.userId]

        XCTAssertEqual(timeProvider.presentTime.timeIntervalSince1970, updated!.timeIntervalSince1970, accuracy: 1.0)
    }

    /// `didRegister(withToken:)` passes the token to the notification service.
    func test_didRegister() throws {
        let tokenData = try XCTUnwrap("tokensForFree".data(using: .utf8))

        let task = Task {
            subject.didRegister(withToken: tokenData)
        }

        waitFor(notificationService.registrationTokenData == tokenData)
        task.cancel()
    }

    /// `failedToRegister(_:)` records the error.
    func test_failedToRegister() {
        subject.failedToRegister(BitwardenTestError.example)
        XCTAssertEqual(errorReporter.errors.last as? BitwardenTestError, .example)
    }

    /// `messageReceived(_:notificationDismissed:notificationTapped)` passes the data to the notification service.
    func test_messageReceived() async {
        let message: [AnyHashable: Any] = ["knock knock": "who's there?"]

        await subject.messageReceived(message)

        XCTAssertEqual(notificationService.messageReceivedMessage?.keys.first, "knock knock")
    }

    /// Upon a session timeout on app foreground, send the user to the `.didTimeout` route.
    func test_shouldSessionTimeout_navigateTo_didTimeout() throws {
        let rootNavigator = MockRootNavigator()
        let account: Account = .fixture()

        appSettingStore.timeoutAction[account.profile.userId] = SessionTimeoutAction.lock.rawValue
        appSettingStore.state = State(
            accounts: [account.profile.userId: account],
            activeUserId: account.profile.userId
        )
        stateService.activeAccount = account
        stateService.accounts = [account]

        vaultTimeoutService.shouldSessionTimeout[account.profile.userId] = true
        subject.start(appContext: .mainApp, navigator: rootNavigator, window: nil)

        notificationCenterService.willEnterForegroundSubject.send()
        waitFor(vaultTimeoutService.shouldSessionTimeout[account.profile.userId] == true)

        waitFor(appModule.appCoordinator.routes.last != .auth(.didStart))
        XCTAssertEqual(
            appModule.appCoordinator.routes.last,
            .auth(.didTimeout(userId: account.profile.userId))
        )
    }

    /// `showLoginRequest(_:)` navigates to show the login request view.
    func test_showLoginRequest() {
        subject.showLoginRequest(.fixture())
        XCTAssertEqual(coordinator.routes.last, .loginRequest(.fixture()))
    }

    /// `start(navigator:)` builds the AppCoordinator and navigates to the initial route if provided.
    func test_start_initialRoute() {
        let rootNavigator = MockRootNavigator()

        subject.start(
            appContext: .mainApp,
            initialRoute: .extensionSetup(.extensionActivation(type: .appExtension)),
            navigator: rootNavigator,
            window: nil
        )

        XCTAssertTrue(appModule.appCoordinator.isStarted)
        XCTAssertEqual(
            appModule.appCoordinator.routes,
            [.extensionSetup(.extensionActivation(type: .appExtension))]
        )
    }

    /// `start(navigator:)` builds the AppCoordinator and navigates to the `.didStart` route.
    func test_start_authRoute() {
        let rootNavigator = MockRootNavigator()

        subject.start(appContext: .mainApp, navigator: rootNavigator, window: nil)

        XCTAssertTrue(appModule.appCoordinator.isStarted)
        XCTAssertEqual(appModule.appCoordinator.routes, [.auth(.didStart)])
    }
}
