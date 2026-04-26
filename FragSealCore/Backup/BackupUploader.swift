//
//  BackupUploader.swift
//  FragSealCore
//

import Foundation
import System
import FragSealFileSystem

public actor BackupUploader {
    public enum Error: Swift.Error {
        case unsupportedAlgorithm(EncryptionMode)
        case invalidChunkSize(Int)
        case passphraseRequired
        case cryptoUnavailable(EncryptionMode)
    }

    private let iterations: UInt32 = 600_000

    public init() {}

    @discardableResult
    public func upload(input: FilePath,
                       manifestPath: FilePath,
                       storageURI: URL,
                       algorithm: EncryptionMode = .aes256Gcm,
                       chunkSize: Int = 64 * 1024 * 1024,
                       region: String? = nil,
                       endpoint: URL? = nil,
                       passphrase: String? = nil) async throws -> BackupManifest {
        guard chunkSize > 0 else {
            throw Error.invalidChunkSize(chunkSize)
        }
        guard algorithm.isWritable else {
            throw Error.unsupportedAlgorithm(algorithm)
        }
        guard ChunkCrypter.supportsEncryption(algorithm) else {
            throw Error.cryptoUnavailable(algorithm)
        }

        let inputURL = URL(fileURLWithPath: input.string)
        let inputData = try Data(contentsOf: inputURL)
        let backupID = UUID().uuidString.lowercased()
        let sourceName = input.lastComponent?.string ?? input.string
        let originalHash = try (algorithm == .none ? "" : ChunkCrypter.sha256Hex(of: inputData))
        let descriptor = try StorageDescriptor.uploadDescriptor(
            for: storageURI,
            backupID: backupID,
            region: region,
            endpoint: endpoint
        )
        let storage = try ObjectStorageFactory.make(from: descriptor)

        let crypter: ChunkCrypter?
        let salt: Data
        let wrappedKey: Data
        let configuredIterations: UInt32
        if algorithm == .none {
            crypter = nil
            salt = Data()
            wrappedKey = Data()
            configuredIterations = 1
        } else {
            guard let passphrase, !passphrase.isEmpty else {
                throw Error.passphraseRequired
            }
            let dataKey = try ChunkCrypter.randomKey(for: algorithm)
            salt = try ChunkCrypter.randomBytes(count: 16)
            let wrappingKey = try ChunkCrypter.deriveWrappingKey(
                passphrase: passphrase,
                salt: salt,
                iterations: iterations
            )
            wrappedKey = try await ChunkCrypter.wrapKey(dataKey, with: wrappingKey)
            crypter = try ChunkCrypter(mode: algorithm, key: dataKey)
            configuredIterations = iterations
        }

        let requests = stride(from: 0, to: inputData.count, by: chunkSize).enumerated().map { ordinal, offset in
            let upperBound = min(offset + chunkSize, inputData.count)
            return ChunkUploader.Request(
                index: ordinal,
                offset: offset,
                objectKey: descriptor.chunkObjectKey(at: ordinal),
                plaintext: Data(inputData[offset..<upperBound])
            )
        }

        print("Uploading \(requests.count) chunks from \(sourceName)")
        let chunkUploader = ChunkUploader(storage: storage, mode: algorithm, crypter: crypter)
        let chunks = try await chunkUploader.upload(requests)

        let manifest = BackupManifest(
            backup: BackupDescriptor(
                id: backupID,
                sourceName: sourceName,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                chunkSize: chunkSize,
                originalSize: inputData.count,
                originalSha256: originalHash
            ),
            storage: descriptor,
            encryption: EncryptionDescriptor(
                mode: algorithm,
                kdf: .pbkdf2Sha256,
                salt: salt.base64EncodedStringValue,
                iterations: configuredIterations,
                wrappedKey: wrappedKey.base64EncodedStringValue
            ),
            chunks: chunks
        )

        let encodedManifest = try TomlManifestCodec.encode(manifest)
        try manifestPath.removingLastComponent().createDirectory(recursive: true)
        try TomlManifestCodec.write(manifest, to: manifestPath)
        try await storage.putObject(key: descriptor.manifestObjectKeyValue, data: encodedManifest)
        return manifest
    }
}

extension BackupUploader.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedAlgorithm(let mode):
            return "Unsupported upload algorithm: \(mode.rawValue)"
        case .invalidChunkSize(let size):
            return "Invalid chunk size: \(size). Expected a positive integer."
        case .passphraseRequired:
            return "Passphrase is required for encrypted uploads."
        case .cryptoUnavailable(let mode):
            return "Crypto runtime for \(mode.rawValue) is unavailable. Install OpenSSL or use --algorithm none."
        }
    }
}
