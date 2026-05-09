import Foundation
import Testing
@testable import JerboaCLI

@Suite("JerboaCLI")
struct JerboaCLITests {
    private let cwd = "/home/reader/notes"

    // MARK: - Help

    @Test func longFlagShowsHelp() {
        #expect(JerboaCLI.parse(arguments: ["--help"], cwd: cwd) == .showHelp)
    }

    @Test func shortFlagShowsHelp() {
        #expect(JerboaCLI.parse(arguments: ["-h"], cwd: cwd) == .showHelp)
    }

    @Test func helpFlagAmongOtherArgsStillShowsHelp() {
        // The CLI is forgiving — if --help is anywhere in argv we show help.
        #expect(JerboaCLI.parse(arguments: ["a.md", "--help"], cwd: cwd) == .showHelp)
    }

    // MARK: - Empty / launch

    @Test func noArgsLaunches() {
        #expect(JerboaCLI.parse(arguments: [], cwd: cwd) == .launch)
    }

    @Test func onlyDashFlagsLaunches() {
        // Apple ships `-NSDocumentRevisionsDebugMode YES` style flags through
        // argv. We strip anything starting with '-'; what's left is no files,
        // so we launch with nothing open.
        #expect(
            JerboaCLI.parse(arguments: ["-ApplePersistenceIgnoreState", "YES"], cwd: cwd)
                == .launch
        )
    }

    // MARK: - Files

    @Test func relativeFilePathResolvesAgainstCWD() {
        #expect(
            JerboaCLI.parse(arguments: ["notes.md"], cwd: cwd)
                == .openFiles(["/home/reader/notes/notes.md"])
        )
    }

    @Test func absoluteFilePathPassesThrough() {
        #expect(
            JerboaCLI.parse(arguments: ["/tmp/spec.md"], cwd: cwd)
                == .openFiles(["/tmp/spec.md"])
        )
    }

    @Test func multipleFilesPreserveOrder() {
        #expect(
            JerboaCLI.parse(arguments: ["a.md", "b.md", "/etc/c.md"], cwd: cwd)
                == .openFiles([
                    "/home/reader/notes/a.md",
                    "/home/reader/notes/b.md",
                    "/etc/c.md",
                ])
        )
    }

    @Test func dashFlagsAndTheirValuesAreSkipped() {
        // macOS framework flags like `-ApplePersistenceIgnoreState YES` show up
        // in argv before our positional file paths. The parser treats every
        // dashed arg as a flag that takes one value, so the flag name AND its
        // value are skipped — only `notes.md` makes it through.
        #expect(
            JerboaCLI.parse(
                arguments: ["-ApplePersistenceIgnoreState", "YES", "notes.md"],
                cwd: cwd
            )
                == .openFiles(["/home/reader/notes/notes.md"])
        )
    }

    @Test func multipleDashFlagsBeforeFile() {
        #expect(
            JerboaCLI.parse(
                arguments: ["-Foo", "1", "-Bar", "2", "doc.md"],
                cwd: cwd
            )
                == .openFiles(["/home/reader/notes/doc.md"])
        )
    }
}
