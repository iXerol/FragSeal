//
//  BackupDownloader.swift
//  FragSealCore
//

import Foundation
import System

public actor BackupDownloader {
    public enum Error: Swift.Error {
        case hashMismatch
    }

    public init() {}

    public func download(manifestPath: FilePath,
                         output: FilePath,
                         passphrase: String) async throws {
        let manifest = try TomlManifestCodec.read(from: manifestPath)
        let storage = try ObjectStorageFactory.make(from: manifest.storage)
        let salt = try Data(base64EncodedOrThrow: manifest.encryption.saltValue)
        let wrappedKey = try Data(base64EncodedOrThrow: manifest.encryption.wrappedKeyValue)
        let wrappingKey = try ChunkCrypter.deriveWrappingKey(
            passphrase: passphrase,
            salt: salt,
            iterations: manifest.encryption.iterations
        )
        let dataKey = try await ChunkCrypter.unwrapKey(wrappedKey, with: wrappingKey)
        let crypter = try ChunkCrypter(mode: manifest.encryption.mode, key: dataKey)
        let downloader = ChunkDownloader(storage: storage, crypter: crypter)
        try await downloader.download(chunks: manifest.chunks, to: output)

        let outputData = try Data(contentsOf: URL(fileURLWithPath: output.string))
        guard try ChunkCrypter.sha256Hex(of: outputData) == manifest.backup.originalSha256Value else {
            throw Error.hashMismatch
        }
        print("Restored \(manifest.backup.sourceNameValue) to \(output.string)")
    }
}
