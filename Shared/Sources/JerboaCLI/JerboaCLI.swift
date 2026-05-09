import Foundation

/// What the CLI argv resolves to.
public enum CLIAction: Equatable, Sendable {
    /// `jerboa --help` / `jerboa -h` — print usage and exit.
    case showHelp
    /// `jerboa file1.md [file2.md ...]` — open one or more documents at the
    /// given absolute paths. Relative paths in argv are resolved against cwd.
    case openFiles([String])
    /// `jerboa` with no positional args — bring up an empty Jerboa, no
    /// document yet.
    case launch
}

/// Pure parser for Jerboa's command-line arguments.
///
/// Side-effects (printing usage, exiting, forwarding to a running instance)
/// stay in `AppDelegate`; this module just decides what the argv means.
public enum JerboaCLI {
    /// Help text printed for `--help`. Kept here so callers don't have to
    /// duplicate it.
    public static let helpText = """
        Usage: jerboa [file ...]

        Open markdown files in Jerboa.

          jerboa file.md            Open a file
          jerboa file1.md file2.md  Open multiple files
          jerboa                    Launch Jerboa
          jerboa --help             Show this help
        """

    public static func parse(
        arguments: [String],
        cwd: String
    ) -> CLIAction {
        if arguments.contains("--help") || arguments.contains("-h") {
            return .showHelp
        }
        // macOS frameworks pass argv like `-ApplePersistenceIgnoreState YES file.md`.
        // Each dashed flag here takes one value, so we skip both the flag and the
        // following arg. Remaining positionals are files. Jerboa's only own flag
        // is --help/-h which is handled above and never reaches this loop.
        var files: [String] = []
        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            if arg.hasPrefix("-") {
                index += 2  // skip flag + its value
            } else {
                files.append(arg.hasPrefix("/") ? arg : cwd + "/" + arg)
                index += 1
            }
        }
        return files.isEmpty ? .launch : .openFiles(files)
    }
}
