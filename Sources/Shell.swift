import Foundation

@discardableResult
func runShell(_ path: String, args: [String], timeout: TimeInterval = 5.0) -> String {
    runShellEx(path, args: args, timeout: timeout).output
}

@discardableResult
func runShellEx(_ path: String, args: [String], timeout: TimeInterval = 5.0) -> (output: String, exitCode: Int32) {
    guard FileManager.default.isExecutableFile(atPath: path) else { return ("", -1) }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let outPipe = Pipe()
    let errPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = errPipe
    do {
        try p.run()
    } catch {
        return ("", -1)
    }
    let deadline = Date().addingTimeInterval(timeout)
    while p.isRunning && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.05)
    }
    if p.isRunning {
        p.terminate()
        return ("", -1)
    }
    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    return (String(data: data, encoding: .utf8) ?? "", p.terminationStatus)
}

