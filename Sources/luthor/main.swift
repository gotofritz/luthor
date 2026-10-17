import Foundation
import LuthorCLI

let result = CLI(environment: ProcessInfo.processInfo.environment, ids: UUIDGenerator())
  .run(Array(CommandLine.arguments.dropFirst()))
FileHandle.standardOutput.write(Data(result.output.utf8))
FileHandle.standardError.write(Data(result.error.utf8))
exit(result.exitCode)
