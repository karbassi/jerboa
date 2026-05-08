import Combine
import Foundation

/// The disposition of a window with respect to its backing file.
///
/// - `reading`: the rendered Document matches the file on disk.
/// - `pendingReload`: the file changed on disk after the last render; the Reader can apply a
///   Pending Reload to render the new version.
/// - `missing`: the file is no longer at its path. Terminal — the only way out is for the
///   Reader to re-open the file (which constructs a new state machine in a new window).
///
/// See ADR-0007 for the full rationale and transition table.
public enum DocumentSyncState: Equatable, Sendable {
    case reading
    case pendingReload
    case missing
}

/// Things the outside world tells the state machine.
///
/// `fileChanged` and `fileVanished` come from the file watcher.
/// `reloadSucceeded` and `reloadFailed` come from the Reader-initiated reload action.
public enum DocumentSyncEvent: Equatable, Sendable {
    case fileChanged
    case fileVanished
    case reloadSucceeded
    case reloadFailed
}

/// Implements ADR-0007's Reading | Pending Reload | Missing transition table.
///
/// The transition function is pure (`transition(from:on:)`) — tests can assert against the
/// table without instantiating the machine. Instances publish a `state` so views observe
/// changes through the SwiftUI / Combine machinery.
@MainActor
public final class DocumentSyncStateMachine: ObservableObject {
    @Published public private(set) var state: DocumentSyncState

    public init(initialState: DocumentSyncState = .reading) {
        self.state = initialState
    }

    public func handle(_ event: DocumentSyncEvent) {
        state = Self.transition(from: state, on: event)
    }

    /// Pure transition function. Missing is terminal — every event from Missing returns
    /// Missing. From any other state, the event determines the next state directly.
    public nonisolated static func transition(
        from state: DocumentSyncState,
        on event: DocumentSyncEvent
    ) -> DocumentSyncState {
        if state == .missing { return .missing }
        switch event {
        case .fileChanged:     return .pendingReload
        case .fileVanished:    return .missing
        case .reloadSucceeded: return .reading
        case .reloadFailed:    return .missing
        }
    }
}
