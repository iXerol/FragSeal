//
//  ManifestTests.swift
//  FragSealCoreTests
//

import Foundation
import Testing
@testable import FragSealCore

@Suite
struct ManifestTests {
    @Test
    func manifestRoundTrip() throws {
        let manifest = BackupManifest(
            backup: BackupDescriptor(
                id: "backup-123",
                sourceName: "archive.bin",
                createdAt: "2026-03-07T12:00:00Z",
                chunkSize: 4096,
                originalSize: 8192,
                originalSha256: String(repeating: "a", count: 64)
            ),
            storage: StorageDescriptor(
                backend: .local,
                bucket: nil,
                region: nil,
                prefix: "fragseal/backup-123",
                rootPath: "/tmp/fragseal",
                endpoint: nil
            ),
            encryption: EncryptionDescriptor(
                mode: .aes256Gcm,
                kdf: .pbkdf2Sha256,
                salt: Data([0x01, 0x02]).base64EncodedStringValue,
                iterations: 600_000,
                wrappedKey: Data([0x03, 0x04, 0x05]).base64EncodedStringValue
            ),
            chunks: [
                ChunkDescriptor(
                    index: 0,
                    objectKey: "fragseal/backup-123/chunks/00000000.bin",
                    offset: 0,
                    plaintextSize: 1024,
                    ciphertextSize: 1040,
                    sha256: String(repeating: "b", count: 64),
                    nonce: Data(repeating: 0xaa, count: 12).base64EncodedStringValue,
                    iv: nil
                ),
            ]
        )

        let decoded = try TomlManifestCodec.decode(TomlManifestCodec.encode(manifest))
        #expect(decoded == manifest)
    }
}
