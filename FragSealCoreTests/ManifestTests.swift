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
    func decodeManifestWithExplicitNoneMode() throws {
        let toml = """
        version = 1

        [backup]
        id = "backup-none-explicit"
        source_name = "archive.bin"
        created_at = "2026-03-07T12:00:00Z"
        chunk_size = 1024
        original_size = 1024

        [storage]
        backend = "local"
        prefix = "fragseal/backup-none-explicit"
        root_path = "/tmp/fragseal"

        [encryption]
        mode = "none"

        [[chunks]]
        index = 0
        object_key = "fragseal/backup-none-explicit/chunks/00000000.bin"
        offset = 0
        plaintext_size = 1024
        ciphertext_size = 1024
        """

        let decoded = try TomlManifestCodec.decode(Data(toml.utf8))
        #expect(decoded.encryption.mode == .none)
        #expect(decoded.encryption.saltValue.isEmpty)
        #expect(decoded.encryption.wrappedKeyValue.isEmpty)
        #expect(decoded.encryption.iterations == 1)
        #expect(decoded.backup.originalSha256Value.isEmpty)
        #expect(decoded.chunks[0].sha256Value.isEmpty)
    }

    @Test
    func decodeNoneModeRejectsZeroIterationsWhenProvided() {
        let toml = """
        version = 1

        [backup]
        id = "backup-none-invalid"
        source_name = "archive.bin"
        created_at = "2026-03-07T12:00:00Z"
        chunk_size = 1024
        original_size = 1024

        [storage]
        backend = "local"
        prefix = "fragseal/backup-none-invalid"
        root_path = "/tmp/fragseal"

        [encryption]
        mode = "none"
        iterations = 0

        [[chunks]]
        index = 0
        object_key = "fragseal/backup-none-invalid/chunks/00000000.bin"
        offset = 0
        plaintext_size = 1024
        ciphertext_size = 1024
        """

        #expect(throws: Error.self) {
            _ = try TomlManifestCodec.decode(Data(toml.utf8))
        }
    }

    @Test
    func decodeEncryptedChunkRequiresNonceForAeadModes() {
        let toml = """
        version = 1

        [backup]
        id = "backup-aead-invalid"
        source_name = "archive.bin"
        created_at = "2026-03-07T12:00:00Z"
        chunk_size = 1024
        original_size = 1024
        original_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

        [storage]
        backend = "local"
        prefix = "fragseal/backup-aead-invalid"
        root_path = "/tmp/fragseal"

        [encryption]
        mode = "aes-256-gcm"
        kdf = "pbkdf2-sha256"
        salt = "AQI="
        iterations = 600000
        wrapped_key = "AwQF"

        [[chunks]]
        index = 0
        object_key = "fragseal/backup-aead-invalid/chunks/00000000.bin"
        offset = 0
        plaintext_size = 1024
        ciphertext_size = 1040
        sha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        """

        #expect(throws: Error.self) {
            _ = try TomlManifestCodec.decode(Data(toml.utf8))
        }
    }

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

    @Test
    func manifestRoundTripWithoutEncryption() throws {
        let manifest = BackupManifest(
            backup: BackupDescriptor(
                id: "backup-none",
                sourceName: "archive.bin",
                createdAt: "2026-03-07T12:00:00Z",
                chunkSize: 4096,
                originalSize: 4096,
                originalSha256: ""
            ),
            storage: StorageDescriptor(
                backend: .local,
                bucket: nil,
                region: nil,
                prefix: "fragseal/backup-none",
                rootPath: "/tmp/fragseal",
                endpoint: nil
            ),
            encryption: EncryptionDescriptor(
                mode: .none,
                kdf: .pbkdf2Sha256,
                salt: "",
                iterations: 1,
                wrappedKey: ""
            ),
            chunks: [
                ChunkDescriptor(
                    index: 0,
                    objectKey: "fragseal/backup-none/chunks/00000000.bin",
                    offset: 0,
                    plaintextSize: 1024,
                    ciphertextSize: 1024,
                    sha256: "",
                    nonce: nil,
                    iv: nil
                ),
            ]
        )

        let encoded = try TomlManifestCodec.encode(manifest)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        #expect(encodedString.contains("[encryption]"))
        #expect(!encodedString.contains("mode ="))
        let decoded = try TomlManifestCodec.decode(encoded)
        #expect(decoded == manifest)
    }
}
