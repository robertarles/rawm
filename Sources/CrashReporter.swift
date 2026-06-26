import Foundation
import Darwin

// File-scope globals — must be at module level so @convention(c) signal handlers can read them
// (Swift closures used as C function pointers cannot capture variables)
private var _crashLogFd: Int32 = -1
private var _crashHandled: Int32 = 0
// Pre-allocated so signal handler never calls malloc
private var _backtraceBuffer = [UnsafeMutableRawPointer?](repeating: nil, count: 128)

enum CrashReporter {

    static func install() {
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("rawm-crash.log")
        _crashLogFd = logURL.path.withCString { open($0, O_WRONLY | O_CREAT | O_APPEND, 0o644) }
        if _crashLogFd < 0 {
            NSLog("rawm CrashReporter: failed to open log at %@", logURL.path)
        }

        NSSetUncaughtExceptionHandler { exc in
            guard OSAtomicCompareAndSwap32(0, 1, &_crashHandled) else { return }
            CrashReporter.writeExceptionEntry(exc)
        }

        let sigHandler: @convention(c) (Int32) -> Void = { sig in
            if OSAtomicCompareAndSwap32(0, 1, &_crashHandled) {
                CrashReporter.writeSignalEntry(sig)
            }
            signal(sig, SIG_DFL)
            raise(sig)
        }
        for sig in [SIGABRT, SIGSEGV, SIGILL, SIGBUS, SIGFPE] {
            signal(sig, sigHandler)
        }
    }

    // Called from NSException handler — full Foundation available
    fileprivate static func writeExceptionEntry(_ exc: NSException) {
        guard _crashLogFd >= 0 else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = """

================================================================================
rawm Crash Report
Timestamp:   \(timestamp)
App Version: \(version) (\(build))
Crash Type:  NSException — \(exc.name.rawValue)
Reason:      \(exc.reason ?? "(none)")
================================================================================
\(exc.callStackSymbols.joined(separator: "\n"))
================================================================================
[end of crash report]

"""
        writeStr(entry)
    }

    // Called from signal handler — async-signal-safe only: write(), backtrace(), StaticString
    fileprivate static func writeSignalEntry(_ sig: Int32) {
        guard _crashLogFd >= 0 else { return }
        writeLit("\n================================================================================\n")
        writeLit("rawm Crash Report\nCrash Type:  Signal — ")
        switch sig {
        case SIGABRT: writeLit("SIGABRT (likely Swift fatalError or abort)\n")
        case SIGSEGV: writeLit("SIGSEGV (segmentation fault)\n")
        case SIGILL:  writeLit("SIGILL (illegal instruction)\n")
        case SIGBUS:  writeLit("SIGBUS (bus error)\n")
        case SIGFPE:  writeLit("SIGFPE (floating point exception)\n")
        default:      writeLit("(unknown signal)\n")
        }
        writeLit("================================================================================\n")
        let frameCount = _backtraceBuffer.withUnsafeMutableBufferPointer {
            backtrace($0.baseAddress, Int32($0.count))
        }
        _backtraceBuffer.withUnsafeMutableBufferPointer {
            backtrace_symbols_fd($0.baseAddress, frameCount, _crashLogFd)
        }
        writeLit("================================================================================\n")
        writeLit("[end of crash report]\n\n")
    }

    // Writes a Swift String to the log fd via write() — safe for NSException handler
    private static func writeStr(_ s: String) {
        s.withCString { ptr in
            var remaining = strlen(ptr)
            var offset = 0
            while remaining > 0 {
                let written = write(_crashLogFd, ptr + offset, remaining)
                guard written > 0 else { break }
                remaining -= written
                offset += written
            }
        }
    }

    // Writes a StaticString literal to the log fd — safe in signal handler (no allocation)
    private static func writeLit(_ s: StaticString) {
        s.withUTF8Buffer { buf in
            guard let base = buf.baseAddress else { return }
            var remaining = buf.count
            var offset = 0
            while remaining > 0 {
                let written = write(_crashLogFd, base + offset, remaining)
                guard written > 0 else { break }
                remaining -= written
                offset += written
            }
        }
    }
}
