import Foundation

struct CommandResult: Sendable {
    let output: String
    let errorOutput: String
    let exitCode: Int32
}

enum CommandRunnerError: LocalizedError {
    case launch(String)
    case failed(String, Int32)

    var errorDescription: String? {
        switch self {
        case .launch(let message): return message
        case .failed(let message, _): return message
        }
    }
}

enum CommandRunner {
    static func run(
        _ executable: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        allowFailure: Bool = false
    ) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let captureDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("rokid-command-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: captureDirectory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: captureDirectory) }

            let stdoutURL = captureDirectory.appendingPathComponent("stdout")
            let stderrURL = captureDirectory.appendingPathComponent("stderr")
            fileManager.createFile(atPath: stdoutURL.path, contents: nil)
            fileManager.createFile(atPath: stderrURL.path, contents: nil)
            let stdout = try FileHandle(forWritingTo: stdoutURL)
            let stderr = try FileHandle(forWritingTo: stderrURL)

            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr
            if let environment { process.environment = environment }

            do {
                try process.run()
            } catch {
                try? stdout.close()
                try? stderr.close()
                throw CommandRunnerError.launch(error.localizedDescription)
            }

            process.waitUntilExit()
            try? stdout.close()
            try? stderr.close()
            let output = String(data: (try? Data(contentsOf: stdoutURL)) ?? Data(), encoding: .utf8)?.trimmed ?? ""
            let errorOutput = String(data: (try? Data(contentsOf: stderrURL)) ?? Data(), encoding: .utf8)?.trimmed ?? ""
            let result = CommandResult(output: output, errorOutput: errorOutput, exitCode: process.terminationStatus)
            if !allowFailure && result.exitCode != 0 {
                throw CommandRunnerError.failed(errorOutput.isEmpty ? output : errorOutput, result.exitCode)
            }
            return result
        }.value
    }

    static func shell(_ command: String, allowFailure: Bool = false) async throws -> CommandResult {
        try await run(URL(fileURLWithPath: "/bin/zsh"), arguments: ["-lc", command], allowFailure: allowFailure)
    }
}
