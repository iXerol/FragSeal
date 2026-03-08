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
                       passphrase: String) async throws -> BackupManifest {
        guard chunkSize > 0 else {
            throw Error.invalidChunkSize(chunkSize)
        }
        guard algorithm.isWritable else {
            throw Error.unsupportedAlgorithm(algorithm)
        }

        let inputURL = URL(fileURLWithPath: input.string)
        let inputData = try Data(contentsOf: inputURL)
        let backupID = UUID().uuidString.lowercased()
        let sourceName = input.lastComponent?.string ?? input.string
        let originalHash = try ChunkCrypter.sha256Hex(of: inputData)
        let descriptor = try StorageDescriptor.uploadDescriptor(
            for: storageURI,
            backupID: backupID,
            region: region,
            endpoint: endpoint
        )
        let storage = try ObjectStorageFactory.make(from: descriptor)

        let dataKey = try ChunkCrypter.randomKey(for: algorithm)
        let salt = try ChunkCrypter.randomBytes(count: 16)
        let wrappingKey = try ChunkCrypter.deriveWrappingKey(
            passphrase: passphrase,
            salt: salt,
            iterations: iterations
        )
        let wrappedKey = try await ChunkCrypter.wrapKey(dataKey, with: wrappingKey)
        let crypter = try ChunkCrypter(mode: algorithm, key: dataKey)

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
        let chunkUploader = ChunkUploader(storage: storage, crypter: crypter)
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
                iterations: iterations,
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
