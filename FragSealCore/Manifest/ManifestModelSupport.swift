//
//  ManifestModelSupport.swift
//  FragSealCore
//

import CxxStdlib
import Foundation
import System
import FragSealFileSystem
import FragSealTomlCodec

public enum ManifestModelError: Error {
    case invalidStorageURI(URL)
    case invalidStorageDescriptor(StorageDescriptor)
    case invalidBase64(String)
}

enum ManifestChunkError: Error {
    case missingNonce(Int)
    case missingIV(Int)
}

extension BackupDescriptor {
    init(id: String,
         sourceName: String,
         createdAt: String,
         chunkSize: Int,
         originalSize: Int,
         originalSha256: String) {
        self.init(
            id: std.string(id),
            sourceName: std.string(sourceName),
            createdAt: std.string(createdAt),
            chunkSize: Int64(chunkSize),
            originalSize: Int64(originalSize),
            originalSha256: std.string(originalSha256)
        )
    }
}

extension StorageDescriptor {
    init(backend: StorageBackend,
         bucket: String?,
         region: String?,
         prefix: String,
         rootPath: String?,
         endpoint: String?) {
        self.init(
            backend: backend,
            bucket: OptionalString(bucket),
            region: OptionalString(region),
            prefix: std.string(prefix),
            rootPath: OptionalString(rootPath),
            endpoint: OptionalString(endpoint)
        )
    }
}

extension EncryptionDescriptor {
    init(mode: EncryptionMode,
         kdf: KeyDerivationAlgorithm,
         salt: String,
         iterations: UInt32,
         wrappedKey: String) {
        self.init(
            mode: mode,
            kdf: kdf,
            salt: std.string(salt),
            iterations: iterations,
            wrappedKey: std.string(wrappedKey)
        )
    }
}

extension ChunkDescriptor {
    init(index: Int,
         objectKey: String,
         offset: Int,
         plaintextSize: Int,
         ciphertextSize: Int,
         sha256: String,
         nonce: String?,
         iv: String?) {
        self.init(
            index: Int64(index),
            objectKey: std.string(objectKey),
            offset: Int64(offset),
            plaintextSize: Int64(plaintextSize),
            ciphertextSize: Int64(ciphertextSize),
            sha256: std.string(sha256),
            nonce: OptionalString(nonce),
            iv: OptionalString(iv)
        )
    }
}

extension BackupManifest {
    init(version: Int = 1,
         backup: BackupDescriptor,
         storage: StorageDescriptor,
         encryption: EncryptionDescriptor,
         chunks: some Sequence<ChunkDescriptor>) {
        self.init(
            version: Int64(version),
            backup: backup,
            storage: storage,
            encryption: encryption,
            chunks: ChunkList(chunks)
        )
    }
}

public extension StorageDescriptor {
    var bucketValue: String? { bucket.stringValue }
    var regionValue: String? { region.stringValue }
    var rootPathValue: String? { rootPath.stringValue }
    var endpointValue: String? { endpoint.stringValue }
    var manifestObjectKeyValue: String { manifestObjectKey().stringValue }

    func chunkObjectKey(at index: Int) -> String {
        chunkObjectKey(index: Int64(index)).stringValue
    }

    static func uploadDescriptor(for storageURI: URL,
                                 backupID: String,
                                 region: String?,
                                 endpoint: URL?) throws -> StorageDescriptor {
        switch storageURI.scheme?.lowercased() {
        case "s3":
            guard let bucket = storageURI.host, !bucket.isEmpty else {
                throw ManifestModelError.invalidStorageURI(storageURI)
            }

            let trimmedPrefix = storageURI.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let basePrefix = trimmedPrefix.isEmpty ? "fragseal" : trimmedPrefix
            return StorageDescriptor(
                backend: .s3,
                bucket: bucket,
                region: region,
                prefix: "\(basePrefix)/\(backupID)",
                rootPath: nil,
                endpoint: endpoint?.absoluteString
            )
        case "file":
            return StorageDescriptor(
                backend: .local,
                bucket: nil,
                region: nil,
                prefix: "fragseal/\(backupID)",
                rootPath: storageURI.path,
                endpoint: nil
            )
        default:
            throw ManifestModelError.invalidStorageURI(storageURI)
        }
    }

    func resolvedManifestPath() throws -> FilePath {
        guard backend == .local, let manifestPath = localManifestPathString().stringValue else {
            throw ManifestModelError.invalidStorageDescriptor(self)
        }
        return FilePath(manifestPath)
    }
}

public extension BackupDescriptor {
    var sourceNameValue: String { sourceName.stringValue }
    var originalSha256Value: String { originalSha256.stringValue }
}

public extension EncryptionDescriptor {
    var saltValue: String { salt.stringValue }
    var wrappedKeyValue: String { wrappedKey.stringValue }
}

public extension EncryptionMode {
    var rawValue: String {
        encryptionModeRawValueString(self).stringValue
    }

    var keySize: Int {
        Int(encryptionModeKeySize(self))
    }

    var nonceSize: Int {
        Int(encryptionModeNonceSize(self))
    }

    var isWritable: Bool {
        encryptionModeIsWritable(self)
    }
}

public extension ChunkDescriptor {
    var objectKeyValue: String { objectKey.stringValue }
    var sha256Value: String { sha256.stringValue }

    func nonceOrIV(for mode: EncryptionMode) throws -> Data {
        guard let encoded = nonceOrIVBase64(for: mode).stringValue else {
            switch mode {
            case .legacyAes128Cbc:
                throw ManifestChunkError.missingIV(Int(index))
            case .aes256Gcm, .chacha20Poly1305:
                throw ManifestChunkError.missingNonce(Int(index))
            @unknown default:
                throw ManifestChunkError.missingNonce(Int(index))
            }
        }

        guard let data = Data(base64Encoded: encoded) else {
            throw ManifestModelError.invalidBase64(encoded)
        }
        return data
    }
}

public extension TomlManifestCodec {
    static func write(_ manifest: BackupManifest, to path: FilePath) throws {
        let writer = try FileWriter(path: path, mode: .truncate)
        try writer.append(try encode(manifest))
    }

    static func read(from path: FilePath) throws -> BackupManifest {
        try decode(Data(contentsOf: URL(fileURLWithPath: path.string)))
    }
}
