import Foundation

// Entry point. With a known subcommand we run the CLI; otherwise (e.g. double-clicked
// from /Applications) we launch the SwiftUI app.
let cliArgs = CommandLine.arguments.dropFirst()
let cliCommands: Set<String> = ["list", "test", "blink", "identify", "conduct", "loop", "help", "-h", "--help"]

if let cmd = cliArgs.first, cliCommands.contains(cmd) {
    CLI.run(cmd)
} else {
    DL4App.main()
}
