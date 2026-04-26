//
//  PassphraseReader.swift
//  FragSeal
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

enum PassphraseReader {
    enum Error: Swift.Error {
        case missingPassphrase
        case confirmationMismatch
        case interactiveReadFailed
    }

    static func resolve(confirm: Bool = false) throws -> String {
        if let environmentPassphrase = ProcessInfo.processInfo.environment["FRAGSEAL_PASSPHRASE"],
           !environmentPassphrase.isEmpty {
            return environmentPassphrase
        }

        guard isInteractiveStdin() else {
            throw Error.missingPassphrase
        }

        guard let first = getpass("Passphrase: ") else {
            throw Error.interactiveReadFailed
        }
        let passphrase = String(cString: first)

        if confirm {
            guard let second = getpass("Confirm passphrase: ") else {
                throw Error.interactiveReadFailed
            }
            guard passphrase == String(cString: second) else {
                throw Error.confirmationMismatch
            }
        }

        return passphrase
    }

    static func isInteractiveStdin() -> Bool {
        isatty(STDIN_FILENO) == 1
    }
}
