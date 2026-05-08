import Testing
@testable import DocumentSync

@Suite("DocumentSyncStateMachine — ADR-0007 transition table")
struct DocumentSyncTransitionTests {
    typealias State = DocumentSyncState
    typealias Event = DocumentSyncEvent

    // MARK: From Reading

    @Test func reading_fileChanged_goesToPendingReload() {
        #expect(DocumentSyncStateMachine.transition(from: .reading, on: .fileChanged) == .pendingReload)
    }

    @Test func reading_fileVanished_goesToMissing() {
        #expect(DocumentSyncStateMachine.transition(from: .reading, on: .fileVanished) == .missing)
    }

    @Test func reading_reloadSucceeded_staysReading() {
        // No-op event from Reading (reload only initiates from Pending Reload), but the
        // pure function should still return a sensible value.
        #expect(DocumentSyncStateMachine.transition(from: .reading, on: .reloadSucceeded) == .reading)
    }

    @Test func reading_reloadFailed_goesToMissing() {
        // Defensive: if a reload were triggered without a Pending Reload and the file is
        // gone, we should surface Missing.
        #expect(DocumentSyncStateMachine.transition(from: .reading, on: .reloadFailed) == .missing)
    }

    // MARK: From Pending Reload

    @Test func pendingReload_fileChanged_staysPendingReload() {
        #expect(DocumentSyncStateMachine.transition(from: .pendingReload, on: .fileChanged) == .pendingReload)
    }

    @Test func pendingReload_fileVanished_goesToMissing() {
        #expect(DocumentSyncStateMachine.transition(from: .pendingReload, on: .fileVanished) == .missing)
    }

    @Test func pendingReload_reloadSucceeded_goesToReading() {
        #expect(DocumentSyncStateMachine.transition(from: .pendingReload, on: .reloadSucceeded) == .reading)
    }

    @Test func pendingReload_reloadFailed_goesToMissing() {
        #expect(DocumentSyncStateMachine.transition(from: .pendingReload, on: .reloadFailed) == .missing)
    }

    // MARK: Missing is terminal

    @Test(arguments: [Event.fileChanged, .fileVanished, .reloadSucceeded, .reloadFailed])
    func missing_isTerminal_underAnyEvent(event: Event) {
        #expect(DocumentSyncStateMachine.transition(from: .missing, on: event) == .missing)
    }
}

@Suite("DocumentSyncStateMachine — instance behaviour")
@MainActor
struct DocumentSyncInstanceTests {
    @Test func defaultsToReading() {
        let machine = DocumentSyncStateMachine()
        #expect(machine.state == .reading)
    }

    @Test func acceptsExplicitInitialState() {
        let machine = DocumentSyncStateMachine(initialState: .pendingReload)
        #expect(machine.state == .pendingReload)
    }

    @Test func handleAdvancesPublishedState() {
        let machine = DocumentSyncStateMachine()
        machine.handle(.fileChanged)
        #expect(machine.state == .pendingReload)
        machine.handle(.reloadSucceeded)
        #expect(machine.state == .reading)
    }

    @Test func missingIsTerminalOnInstance() {
        let machine = DocumentSyncStateMachine(initialState: .missing)
        machine.handle(.fileChanged)   // would normally → pendingReload
        machine.handle(.reloadSucceeded) // would normally → reading
        #expect(machine.state == .missing)
    }
}
