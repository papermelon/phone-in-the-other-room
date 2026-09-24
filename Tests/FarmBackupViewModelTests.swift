#if FARM_BACKUP_VIEW_MODEL_TESTS
import XCTest
import AuthenticationServices

@MainActor
final class FarmBackupViewModelTests: XCTestCase {
    private var directory: URL!
    private var suite: String!
    private var defaults: UserDefaults!
    private var persistence: PersistenceService!
    private var files: RestoreFailureFiles!
    private var owner: UUID!
    private var account: NightFlockAccountService!
    private var service: FarmBackupService!
    private var model: FarmBackupViewModel!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        suite = UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
        files = RestoreFailureFiles()
        persistence = PersistenceService(defaults: defaults, farmSaveDirectory: directory, farmSaveFiles: files)
        var local = FarmState.empty
        local.woolBalance = 14
        local.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
        persistence.farmState = local
        var remoteFarm = local
        remoteFarm.woolBalance = 300
        let payload = try FarmBackupPayload(document: FarmSaveDocument(lineageID: UUID(), generation: 12,
            values: ["ollie.farm.state": JSONEncoder().encode(remoteFarm)]))
        owner = UUID()
        account = NightFlockAccountService(owner: owner)
        service = FarmBackupService(remote: FarmBackupLookup(capability: "farm_save_v1", generation: UUID(),
            head: FarmBackupRevision(id: UUID(), payload: payload, digest: "test", createdAt: Date(), conflict: false),
            revisions: []))
        model = FarmBackupViewModel(persistence: persistence, account: account, service: service)
        model.permitsTransport = { true }
        model.canRestore = { true }
    }

    override func tearDown() async throws {
        model.pause()
        model = nil
        defaults.removePersistentDomain(forName: suite)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    private func finish() async throws {
        for _ in 0..<200 {
            if !model.busy { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Operation did not finish")
    }

    func testFarmConnectionFailureKeepsAuthenticatedIdentityAndLocalArchive() throws {
        try persistence.farmSaveStore.activate(.account(owner), preservingGuest: true)
        try persistence.farmSaveStore.activate(.signedOut)
        let original = try persistence.farmSaveStore.cachedAccount(owner)
        model.authenticatedAccountID = owner
        model.show(URLError(.badServerResponse))
        XCTAssertEqual(model.authenticatedAccountID, owner)
        XCTAssertFalse(model.signedIn)
        XCTAssertTrue(model.message.contains("account is connected"))
        XCTAssertFalse(model.message.contains("wait for a connection"))
        XCTAssertEqual(try persistence.farmSaveStore.cachedAccount(owner), original)
    }

    private func waitFor(_ condition: @escaping @MainActor () async -> Bool) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition did not become true")
    }

    func testSyncConsentFailureIsVisibleAndRetryClearsNotice() async throws {
        model.signedIn = true
        model.needsSyncAgreement = true
        model.permitsTransport = { false }
        model.acceptAutomaticSync()
        XCTAssertTrue(model.busy)
        try await finish()
        XCTAssertTrue(model.needsSyncAgreement)
        XCTAssertEqual(model.syncConnectionNotice, model.message)
        XCTAssertEqual(model.accountPresentation, .failed)
        model.permitsTransport = { true }
        model.acceptAutomaticSync()
        XCTAssertNil(model.syncConnectionNotice)
        try await finish()
        XCTAssertFalse(model.needsSyncAgreement)
        XCTAssertNil(model.syncConnectionNotice)
    }

    func testSyncConsentExplainsWaitingForCurrentSession() async throws {
        model.signedIn = true
        model.needsSyncAgreement = true
        model.canRestore = { false }
        model.acceptAutomaticSync()
        try await finish()
        XCTAssertTrue(model.needsSyncAgreement)
        XCTAssertEqual(model.syncConnectionNotice, "Finish your current session to load the account’s latest Farm.")
    }

    func testRestorePublishesCommittedFarmEvenWhenPresentationAcknowledgementFails() async throws {
        var displayed = persistence.farmState
        var restoreSuccess: FarmBackupRestoreSuccess?
        var returnerDraft = OnboardingDraft()
        model.didRestore = { [self] in displayed = persistence.farmState }
        model.didCompleteRestore = {
            restoreSuccess = $0
            returnerDraft.beginReturningUserDeviceSetup()
        }
        files.failPresentationAcknowledgement = true
        model.restoreAccountFarm()
        try await finish()
        XCTAssertEqual(displayed.woolBalance, 300)
        XCTAssertEqual(persistence.farmState.woolBalance, 300)
        XCTAssertNotNil(try persistence.farmSaveStore.snapshot().backup?.pendingPresentation)
        XCTAssertTrue(model.message.contains("is restored"))
        XCTAssertEqual(restoreSuccess?.revisionID, try XCTUnwrap(model.lookup?.head?.id))
        XCTAssertNotNil(model.restoreSuccess)
        XCTAssertEqual(returnerDraft.step, .schedule)
        XCTAssertTrue(returnerDraft.returningUserDeviceSetup)
        // The next real Farm mutation uses the restored balance, not the old 14.
        files.failPresentationAcknowledgement = false
        displayed.woolBalance -= 5
        persistence.farmState = displayed
        model.refresh()
        try await finish()
        XCTAssertEqual(persistence.farmState.woolBalance, 295)
        XCTAssertNil(try persistence.farmSaveStore.snapshot().backup?.pendingPresentation)
        let reopened = PersistenceService(defaults: defaults, farmSaveDirectory: directory)
        XCTAssertEqual(reopened.farmState.woolBalance, 295)
    }

    func testFailedRestoreDoesNotPublishOrReplaceLocalFarm() async throws {
        var publications = 0
        model.didRestore = { publications += 1 }
        files.failAll = true
        model.restoreAccountFarm()
        try await finish()
        XCTAssertEqual(publications, 0)
        XCTAssertNil(model.restoreSuccess)
        XCTAssertEqual(persistence.farmState.woolBalance, 14)
        files.failAll = false
    }

    func testDeletionFenceBlocksLookupsUploadsAndPendingRetries() async throws {
        let remote = await service.remote
        let command = FarmBackupCommand(action: "put", generation: remote.generation, operationID: UUID())
        try persistence.farmSaveStore.updateBackup {
            $0 = FarmBackupSync(ownerID: owner, enabled: true, generation: remote.generation, pending: command)
        }
        model.permitsTransport = { false }
        model.refresh()
        try await finish()
        model.retryPending()
        try await finish()
        model.enableBackup()
        try await finish()
        let lookups = await service.lookups, commands = await service.commands
        XCTAssertEqual(lookups, 0)
        XCTAssertTrue(commands.isEmpty)
        XCTAssertEqual(try persistence.farmSaveStore.snapshot().backup?.pending, command)
    }

    func testPauseDuringSessionAcquisitionPreventsPendingUploadPublication() async throws {
        let remote = await service.remote
        try persistence.farmSaveStore.updateBackup {
            $0 = FarmBackupSync(ownerID: owner, enabled: true, generation: remote.generation,
                               baseRevision: remote.head?.id)
        }
        var identityReads = 0
        await account.setBeforeIdentity { [self] in
            identityReads += 1
            if identityReads == 2 { model.pause() }
        }
        model.refresh()
        try await finish()
        XCTAssertNil(try persistence.farmSaveStore.snapshot().backup?.pending)
        let commands = await service.commands
        XCTAssertTrue(commands.isEmpty)
    }

    func testDeletionBeginningDuringServicePreflightRejectsUpload() async throws {
        let remote = await service.remote
        try persistence.farmSaveStore.updateBackup {
            $0 = FarmBackupSync(ownerID: owner, enabled: true, generation: remote.generation,
                               baseRevision: remote.head?.id)
        }
        await service.setBeforeSend { [self] in model.pause(); model.permitsTransport = { false } }
        model.refresh()
        try await finish()
        let commands = await service.commands
        XCTAssertTrue(commands.isEmpty)
        XCTAssertFalse(try XCTUnwrap(persistence.farmSaveStore.snapshot().backup).enabled)
    }

    func testKeepThisFarmOnEmptyAccountDoesNotSelectAgainstStaleNilHead() async throws {
        await service.clearHead()
        model.keepThisFarm()
        try await finish()
        let commands = await service.commands
        XCTAssertEqual(commands.map(\.action), ["put"])
        XCTAssertNotNil(try persistence.farmSaveStore.snapshot().backup?.baseRevision)
        XCTAssertNil(try persistence.farmSaveStore.snapshot().backup?.pending)
        XCTAssertTrue(model.message.contains("saved to your account"))
    }

    func testAccountPreviewIsDerivedFromFetchedPayloadWithoutRestoringIt() async throws {
        let localWool = persistence.farmState.woolBalance
        var onboardingRoute = OnboardingDraft()
        model.didCompleteRestore = { _ in onboardingRoute.beginReturningUserDeviceSetup() }
        model.refresh()
        try await finish()

        XCTAssertEqual(model.accountFarmPreview?.activeSheepCount, 0)
        XCTAssertEqual(model.accountFarmPreview?.woolBalance, 300)
        XCTAssertEqual(model.accountPresentation, .remoteFarm(try XCTUnwrap(model.accountFarmPreview)))
        XCTAssertEqual(persistence.farmState.woolBalance, localWool)
        XCTAssertNil(model.restoreSuccess)
        XCTAssertEqual(onboardingRoute.step, .welcome)
        XCTAssertFalse(onboardingRoute.returningUserDeviceSetup)
    }

    func testSuccessfulEmptyLookupShowsBackupChoiceWithoutRestoreSignal() async throws {
        await service.clearHead()
        model.refresh()
        try await finish()

        XCTAssertEqual(model.accountPresentation, .noRemoteSave)
        XCTAssertNil(model.accountFarmPreview)
        XCTAssertNil(model.restoreSuccess)
    }

    func testFailedLookupDoesNotPretendTheAccountIsEmptyOrPublishAPreview() async throws {
        model.permitsTransport = { false }
        model.refresh()
        try await finish()

        XCTAssertEqual(model.accountPresentation, .failed)
        XCTAssertNil(model.lookup)
        XCTAssertNil(model.accountFarmPreview)
        XCTAssertNil(model.restoreSuccess)
    }

    func testRetryWithoutPendingActionReturnsToAnActionableSignedOutState() async throws {
        model.retryPending()
        try await finish()

        XCTAssertEqual(model.accountPresentation, .signedOut)
        XCTAssertFalse(model.busy)
    }

    func testNoOpConfirmedUploadRestoresConfirmedPresentationAfterBackgroundCheck() async throws {
        let remote = await service.remote
        let document = try persistence.farmSaveStore.snapshot()
        let digest = try model.payload(from: document).fingerprint()
        try persistence.farmSaveStore.updateBackup {
            $0 = FarmBackupSync(
                ownerID: owner,
                enabled: true,
                generation: remote.generation,
                baseRevision: remote.head?.id,
                confirmedDigest: digest,
                confirmedAt: Date()
            )
        }
        model.refresh()
        try await finish()
        let commandsBeforeNoOp = await service.commands
        let confirmedAtBeforeNoOp = try XCTUnwrap(
            persistence.farmSaveStore.snapshot().backup?.confirmedAt
        )

        model.perform { try await self.model.uploadIfEnabled() }
        try await finish()

        guard case .backupConfirmed = model.accountPresentation else {
            return XCTFail("Expected confirmed backup presentation after no-op upload")
        }
        let commandsAfterNoOp = await service.commands
        XCTAssertEqual(commandsAfterNoOp.count, commandsBeforeNoOp.count)
        XCTAssertEqual(
            try persistence.farmSaveStore.snapshot().backup?.confirmedAt,
            confirmedAtBeforeNoOp
        )
        XCTAssertFalse(model.busy)
    }

    func testStagingUploadPublishesPendingPresentationBeforeTransportSends() async throws {
        await service.clearHead()
        var presentationAtSend: FarmBackupAccountPresentation?
        await service.setBeforeSend { [self] in presentationAtSend = model.accountPresentation }

        model.enableBackup()
        try await finish()

        XCTAssertEqual(presentationAtSend, .backupPending)
        guard case .backupConfirmed = model.accountPresentation else {
            return XCTFail("Expected confirmed backup presentation after the staged upload")
        }
    }

    func testAccountSignInLoadsRemoteFarmAndEnablesSyncInOneFlow() async throws {
        model.perform { try await self.model.completeAccountConnection(acceptSync: true) }
        try await finish()
        XCTAssertEqual(persistence.farmState.woolBalance, 300)
        XCTAssertEqual(try persistence.farmSaveStore.snapshot().effectiveScope, .account(owner))
        XCTAssertEqual(try persistence.farmSaveStore.snapshot().backup?.accountSyncVersion, 1)
        XCTAssertTrue(try XCTUnwrap(persistence.farmSaveStore.snapshot().backup).enabled)
        XCTAssertNotNil(model.restoreSuccess)
        XCTAssertFalse(model.accessBlocked)
    }

    func testAppleSignInAfterSignOutRestoresTheSameAccountFarm() async throws {
        model.perform { try await self.model.completeAppleFarmSignIn(identityToken: "first", nonce: "first") }
        try await finish()
        XCTAssertEqual(persistence.farmState.woolBalance, 300)
        model.signOut()
        try await finish()
        XCTAssertFalse(model.signedIn)
        XCTAssertNil(model.authenticatedAccountID)
        XCTAssertFalse(model.hasAuthenticatedAccount)
        XCTAssertTrue(model.accessBlocked)
        model.perform { try await self.model.completeAppleFarmSignIn(identityToken: "second", nonce: "second") }
        try await finish()
        XCTAssertTrue(model.signedIn)
        XCTAssertFalse(model.accessBlocked)
        XCTAssertEqual(try persistence.farmSaveStore.snapshot().effectiveScope, .account(owner))
        XCTAssertEqual(persistence.farmState.woolBalance, 300)
    }

    func testAppleSheetReservesOperationSlotAgainstForegroundRefresh() async throws {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        model.prepareApple(request)
        XCTAssertTrue(model.appleSignInInProgress)
        XCTAssertNotNil(model.nonce)
        model.refresh()
        XCTAssertFalse(model.busy, "Foreground sync must not occupy Apple's completion slot")
        model.completeApple(.failure(NSError(domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.canceled.rawValue)))
        XCTAssertFalse(model.appleSignInInProgress)
        XCTAssertNil(model.nonce)
        model.refresh()
        try await finish()
        XCTAssertTrue(model.signedIn)
    }

    func testCancelledAppleLinkDoesNotLeakIntoNextSignIn() {
        model.linkingApple = true
        model.prepareApple(ASAuthorizationAppleIDProvider().createRequest())
        model.completeApple(.failure(NSError(domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.canceled.rawValue)))
        XCTAssertFalse(model.linkingApple)
        XCTAssertFalse(model.appleSignInInProgress)
        XCTAssertNil(model.appleSignInFailure)
        model.prepareApple(ASAuthorizationAppleIDProvider().createRequest())
        XCTAssertFalse(model.linkingApple)
        XCTAssertTrue(model.appleSignInInProgress)
    }

    func testNativeAppleFailurePreservesOnlyStageAndCode() {
        model.prepareApple(ASAuthorizationAppleIDProvider().createRequest())
        model.completeApple(.failure(NSError(domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.unknown.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Sensitive diagnostic must not enter copy"])))
        XCTAssertEqual(model.appleSignInFailure?.stage, .authorization)
        XCTAssertEqual(model.appleSignInFailure?.code, ASAuthorizationError.unknown.rawValue)
        XCTAssertFalse(model.appleSignInFailure!.supportDetail.contains("Sensitive"))
        XCTAssertFalse(model.appleSignInInProgress)
        XCTAssertNil(model.nonce)
    }

    func testAccountReadShowsAppleIdentityBeforeSyncAcceptance() async throws {
        model.refresh()
        try await finish()
        XCTAssertTrue(model.signedIn)
        XCTAssertTrue(model.needsSyncAgreement)
        XCTAssertEqual(model.credentialProfile?.signInMethodsTitle, "Apple connected")
    }

    func testAppleCompletionPublishesOnlyAfterCommittedOwnerActivation() async throws {
        var callbackScope: AccountFarmScope?
        var callbacks = 0
        model.didSignIn = { [self] in
            callbacks += 1
            callbackScope = try? persistence.farmSaveStore.snapshot().effectiveScope
        }

        model.perform { try await self.model.completeAppleFarmSignIn(identityToken: "test", nonce: "test") }
        try await finish()

        XCTAssertEqual(callbacks, 1)
        XCTAssertEqual(callbackScope, .account(owner))
    }

    func testAppleCompletionLookupFailureDoesNotPublishSignInOrChangeOwner() async throws {
        var callbacks = 0
        model.didSignIn = { callbacks += 1 }
        await service.failNextAccountLookup()

        model.perform { try await self.model.completeAppleFarmSignIn(identityToken: "test", nonce: "test") }
        try await finish()

        XCTAssertEqual(callbacks, 0)
        XCTAssertEqual(try persistence.farmSaveStore.snapshot().effectiveScope, .guest)
        XCTAssertEqual(model.appleSignInFailure?.stage, .farm)
        XCTAssertEqual(model.authenticatedAccountID, owner)
        XCTAssertTrue(model.hasAuthenticatedAccount, "Farm failure must not offer Apple sign-in again")
        XCTAssertFalse(model.signedIn, "Authentication is not permission to publish the Farm")

        model.acceptAutomaticSync()
        try await finish()
        XCTAssertTrue(model.signedIn)
        XCTAssertNil(model.appleSignInFailure)
        XCTAssertEqual(callbacks, 1)
        XCTAssertEqual(persistence.farmState.woolBalance, 300)
    }

    func testCredentialRefreshKeepsConfirmedFarmPresentation() async throws {
        model.perform { try await self.model.completeAccountConnection(acceptSync: true) }
        try await finish()
        let savedPresentation = model.accountPresentation
        model.credentials.showMethods()
        try await finish()
        XCTAssertEqual(model.accountPresentation, savedPresentation)
        XCTAssertEqual(model.credentialProfile?.id, owner)
    }

    func testConnectivityRecoveryAutomaticallyRetriesDirtyFarmUpload() async throws {
        let connectivity = FarmSyncConnectivityService(startMonitoring: false)
        model = FarmBackupViewModel(persistence: persistence, account: account, service: service, connectivity: connectivity)
        model.permitsTransport = { true }
        model.canRestore = { true }
        model.automaticRetryDelay = { _ in .seconds(60) }
        model.perform { try await self.model.completeAccountConnection(acceptSync: true) }
        try await finish()
        var farm = persistence.farmState
        farm.woolBalance += 1
        persistence.farmState = farm
        model.scheduled?.cancel()
        await service.failNextUpload()

        model.perform { try await self.model.uploadIfEnabled() }
        try await finish()
        XCTAssertTrue(model.hasUnsyncedChanges)
        connectivity.reportPath(satisfied: false)
        connectivity.reportPath(satisfied: true)
        try await waitFor { await self.service.commands.count == 1 }

        XCTAssertFalse(model.hasUnsyncedChanges)
    }

    func testSignOutCancelsAutomaticRetryBeforeConnectivityRecovers() async throws {
        let connectivity = FarmSyncConnectivityService(startMonitoring: false)
        model = FarmBackupViewModel(persistence: persistence, account: account, service: service, connectivity: connectivity)
        model.permitsTransport = { true }
        model.canRestore = { true }
        model.automaticRetryDelay = { _ in .seconds(60) }
        model.perform { try await self.model.completeAccountConnection(acceptSync: true) }
        try await finish()
        var farm = persistence.farmState
        farm.woolBalance += 1
        persistence.farmState = farm
        model.scheduled?.cancel()
        await service.failNextUpload()
        model.perform { try await self.model.uploadIfEnabled() }
        try await finish()

        model.signOut()
        try await finish()
        connectivity.reportPath(satisfied: false)
        connectivity.reportPath(satisfied: true)
        try await Task.sleep(for: .milliseconds(30))
        let commands = await service.commands
        XCTAssertTrue(commands.isEmpty)
        XCTAssertEqual(try persistence.farmSaveStore.snapshot().effectiveScope, .signedOut)
    }

    func testAutomaticRetryRejectsCredentialAndCorruptDataFailures() async throws {
        let remote = await service.remote
        try persistence.farmSaveStore.updateBackup {
            $0 = FarmBackupSync(ownerID: owner, enabled: true, generation: remote.generation)
        }
        XCTAssertFalse(model.automaticRetryIsAllowed(for: AccountCredentialError.verifyEmail))
        XCTAssertFalse(model.automaticRetryIsAllowed(for: NightFlockAccountError.reauthenticationRequired))
        XCTAssertFalse(model.automaticRetryIsAllowed(for: FarmSaveError.invalidComponent("ollie.farm.state")))
        XCTAssertFalse(model.automaticRetryIsAllowed(for: FarmSaveError.corrupt))
    }

    func testFailedAccountAdoptionRestoreKeepsThePreviousOwnerAndDoesNotPublish() async throws {
        let previousOwner = UUID()
        try persistence.farmSaveStore.activate(.account(previousOwner))
        var previousFarm = persistence.farmState
        previousFarm.woolBalance = 141
        persistence.farmState = previousFarm
        var publications = 0
        model.didRestore = { publications += 1 }
        files.failAll = true

        model.perform { try await self.model.completeAccountConnection(acceptSync: true) }
        try await finish()

        let committed = try persistence.farmSaveStore.snapshot()
        XCTAssertEqual(committed.effectiveScope, .account(previousOwner))
        XCTAssertEqual(persistence.farmState.woolBalance, 141)
        XCTAssertEqual(publications, 0)
        XCTAssertFalse(model.signedIn)
        files.failAll = false
    }

    func testEmptyRemoteAccountAdoptsTheGuestFarmBeforeAccountRouting() async throws {
        await service.clearHead()
        let guest = try persistence.farmSaveStore.snapshot()
        var displayed = persistence.farmState
        var restored = 0
        var signedIn = 0
        model.didRestore = { [self] in
            restored += 1
            displayed = persistence.farmState
        }
        model.didSignIn = { signedIn += 1 }

        model.perform { try await self.model.completeAccountConnection(acceptSync: true) }
        try await finish()

        let adopted = try persistence.farmSaveStore.snapshot()
        XCTAssertEqual(adopted.effectiveScope, .account(owner))
        XCTAssertEqual(adopted.lineageID, guest.lineageID)
        XCTAssertEqual(displayed.woolBalance, 14)
        XCTAssertEqual(restored, 1)
        XCTAssertEqual(signedIn, 1)
    }

    func testLogoutHidesAccountAndPreservesUnsyncedRecoveryOnlyForItsOwner() async throws {
        model.perform { try await self.model.completeAccountConnection(acceptSync: true) }
        try await finish()
        var farm = persistence.farmState
        farm.woolBalance = 301
        persistence.farmState = farm
        let credentialDefaults = UserDefaults.standard
        credentialDefaults.removeObject(forKey: "ollie.account.pendingVerification")
        credentialDefaults.removeObject(forKey: "ollie.account.pendingEmailChange")
        credentialDefaults.set(["email": "old@example.test", "username": "old_name", "phase": "claimUsername"],
                               forKey: "ollie.account.pendingVerification")
        credentialDefaults.set(["currentEmail": "old@example.test", "targetEmail": "new@example.test", "confirmed": []],
                               forKey: "ollie.account.pendingEmailChange")
        model.signOut()
        try await finish()
        XCTAssertTrue(model.accessBlocked)
        let signedOut = try persistence.farmSaveStore.snapshot()
        XCTAssertEqual(signedOut.effectiveScope, .signedOut)
        XCTAssertTrue(signedOut.values.isEmpty)
        XCTAssertEqual(persistence.farmState, .empty)
        XCTAssertEqual(persistence.userProfile.displayName, "")
        let afterRead = try persistence.farmSaveStore.snapshot()
        XCTAssertEqual(afterRead.effectiveScope, .signedOut)
        XCTAssertEqual(afterRead.generation, signedOut.generation)
        XCTAssertNil(persistence.farmSaveStore.failure)
        XCTAssertNil(credentialDefaults.object(forKey: "ollie.account.pendingVerification"))
        XCTAssertNil(credentialDefaults.object(forKey: "ollie.account.pendingEmailChange"))
        let recovered = try XCTUnwrap(persistence.farmSaveStore.cachedAccount(owner))
        XCTAssertEqual(try JSONDecoder().decode(FarmState.self, from: XCTUnwrap(recovered.values["ollie.farm.state"])).woolBalance, 301)
        model.continueAsGuest()
        XCTAssertFalse(model.accessBlocked)
        XCTAssertNotEqual(persistence.farmState.woolBalance, 301)
    }

    func testAccountAdoptionWaitsForActiveSettlement() async throws {
        model.canRestore = { false }
        model.perform { try await self.model.completeAccountConnection(acceptSync: true) }
        try await finish()
        XCTAssertEqual(persistence.farmState.woolBalance, 14)
        XCTAssertEqual(try persistence.farmSaveStore.snapshot().effectiveScope, .guest)
        XCTAssertNil(model.restoreSuccess)
    }

    func testFailedPauseReportsFailureAndInvalidatesInFlightAuthorization() throws {
        let generation = UUID()
        try persistence.farmSaveStore.updateBackup {
            $0 = FarmBackupSync(ownerID: owner, enabled: true, generation: generation)
        }
        files.failAll = true
        XCTAssertFalse(model.pause())
        XCTAssertTrue(try XCTUnwrap(persistence.farmSaveStore.snapshot().backup).enabled)
        files.failAll = false
        XCTAssertTrue(model.pause())
        XCTAssertFalse(try XCTUnwrap(persistence.farmSaveStore.snapshot().backup).enabled)
    }
}

private final class RestoreFailureFiles: FarmSaveFileAccess {
    var failAll = false
    var failPresentationAcknowledgement = false
    let local = LocalFarmSaveFileAccess()
    func files(in directory: URL) throws -> [URL] { try local.files(in: directory) }
    func read(_ url: URL) throws -> Data { try local.read(url) }
    func remove(_ url: URL) throws { try local.remove(url) }
    func write(_ data: Data, to url: URL) throws {
        if failAll { throw FarmSaveError.unavailable }
        if failPresentationAcknowledgement, url.lastPathComponent.hasPrefix("generation-"),
           let document = try? FarmSaveDocument.decode(data), let backup = document.backup,
           backup.pendingPresentation == nil { throw FarmSaveError.unavailable }
        try local.write(data, to: url)
    }
}
#endif
