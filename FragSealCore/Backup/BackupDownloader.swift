//
//  BackupDownloader.swift
//  FragSealCore
//

import Foundation
import System

public actor BackupDownloader {
    public enum Error: Swift.Error {
        case hashMismatch
        case passphraseRequired
        case cryptoUnavailable(EncryptionMode)
    }

    public init() {}

    public func download(manifestPath: FilePath,
                         output: FilePath,
                         passphrase: String? = nil) async throws {
        let manifest = try TomlManifestCodec.read(from: manifestPath)
        let storage = try ObjectStorageFactory.make(from: manifest.storage)
        let mode = manifest.encryption.mode

        let crypter: ChunkCrypter?
        if mode == .none {
            crypter = nil
        } else {
            guard ChunkCrypter.supportsDecryption(mode) else {
                throw Error.cryptoUnavailable(mode)
            }
            guard let passphrase, !passphrase.isEmpty else {
                throw Error.passphraseRequired
            }

            let salt = try Data(base64EncodedOrThrow: manifest.encryption.saltValue)
            let wrappedKey = try Data(base64EncodedOrThrow: manifest.encryption.wrappedKeyValue)
            let wrappingKey = try ChunkCrypter.deriveWrappingKey(
                passphrase: passphrase,
                salt: salt,
                iterations: manifest.encryption.iterations
            )
            let dataKey = try await ChunkCrypter.unwrapKey(wrappedKey, with: wrappingKey)
            crypter = try ChunkCrypter(mode: mode, key: dataKey)
        }

        let downloader = ChunkDownloader(storage: storage, mode: mode, crypter: crypter)
        try await downloader.download(chunks: manifest.chunks, to: output)

        if mode != .none {
            let outputData = try Data(contentsOf: URL(fileURLWithPath: output.string))
            guard try ChunkCrypter.sha256Hex(of: outputData) == manifest.backup.originalSha256Value else {
                throw Error.hashMismatch
            }
        }
        print("Restored \(manifest.backup.sourceNameValue) to \(output.string)")
    }
}

extension BackupDownloader.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .hashMismatch:
            return "Restored file hash does not match manifest."
        case .passphraseRequired:
            return "Passphrase is required to restore encrypted backups."
        case .cryptoUnavailable(let mode):
            return "Crypto runtime for \(mode.rawValue) is unavailable. Use a build with OpenSSL support."
        }
    }
}
