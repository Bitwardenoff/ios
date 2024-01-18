import BitwardenSdk
import Networking

@testable import BitwardenShared

extension ServiceContainer {
    static func withMocks(
        appSettingsStore: AppSettingsStore = MockAppSettingsStore(),
        authRepository: AuthRepository = MockAuthRepository(),
        authService: AuthService = MockAuthService(),
        biometricsService: BiometricsService = DefaultBiometricsService(),
        captchaService: CaptchaService = MockCaptchaService(),
        cameraService: CameraService = MockCameraService(),
        clientService: ClientService = MockClientService(),
        environmentService: EnvironmentService = MockEnvironmentService(),
        errorReporter: ErrorReporter = MockErrorReporter(),
        generatorRepository: GeneratorRepository = MockGeneratorRepository(),
        httpClient: HTTPClient = MockHTTPClient(),
        pasteboardService: PasteboardService = MockPasteboardService(),
        sendRepository: SendRepository = MockSendRepository(),
        settingsRepository: SettingsRepository = MockSettingsRepository(),
        stateService: StateService = MockStateService(),
        syncService: SyncService = MockSyncService(),
        systemDevice: SystemDevice = MockSystemDevice(),
        timeProvider: TimeProvider = MockTimeProvider(.currentTime),
        tokenService: TokenService = MockTokenService(),
        totpService: TOTPService = MockTOTPService(),
        twoStepLoginService: TwoStepLoginService = MockTwoStepLoginService(),
        vaultRepository: VaultRepository = MockVaultRepository(),
        vaultTimeoutService: VaultTimeoutService = MockVaultTimeoutService(),
        watchService: WatchService = MockWatchService()
    ) -> ServiceContainer {
        ServiceContainer(
            apiService: APIService(
                client: httpClient,
                environmentService: environmentService
            ),
            appIdService: AppIdService(appSettingStore: appSettingsStore),
            appSettingsStore: appSettingsStore,
            authRepository: authRepository,
            authService: authService,
            biometricsService: biometricsService,
            captchaService: captchaService,
            cameraService: cameraService,
            clientService: clientService,
            environmentService: environmentService,
            errorReporter: errorReporter,
            generatorRepository: generatorRepository,
            pasteboardService: pasteboardService,
            sendRepository: sendRepository,
            settingsRepository: settingsRepository,
            stateService: stateService,
            syncService: syncService,
            systemDevice: systemDevice,
            timeProvider: timeProvider,
            tokenService: tokenService,
            totpService: totpService,
            twoStepLoginService: twoStepLoginService,
            vaultRepository: vaultRepository,
            vaultTimeoutService: vaultTimeoutService,
            watchService: watchService
        )
    }
}
