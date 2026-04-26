//
//  CryptoTests.swift
//  FragSealCoreTests
//

import Foundation
import System
import Testing
@testable import FragSealCore

@Suite
struct CryptoTests {
    @Test
    func legacyManifestCanBeRestored() async throws {
        guard ChunkCrypter.supportsDecryption(.legacyAes128Cbc) else { return }
        let plaintext = try Data(contentsOf: TestResources.legacyPlaintextURL)
        let storageRoot = TestResources.legacyPlaintextURL.deletingLastPathComponent()
        let salt = Data(repeating: 0x42, count: 16)
        let wrappingKey = try ChunkCrypter.deriveWrappingKey(
            passphrase: TestResources.legacyPassphrase,
            salt: salt,
            iterations: TestResources.legacyIterations
        )
        let wrappedKey = try await ChunkCrypter.wrapKey(TestResources.legacyKey, with: wrappingKey)
        let manifest = BackupManifest(
            backup: BackupDescriptor(
                id: "legacy-fixture",
                sourceName: "legacy_plaintext.bin",
                createdAt: "2026-03-07T12:00:00Z",
                chunkSize: plaintext.count / 2,
                originalSize: plaintext.count,
                originalSha256: try ChunkCrypter.sha256Hex(of: plaintext)
            ),
            storage: StorageDescriptor(
                backend: .local,
                bucket: nil,
                region: nil,
                prefix: "legacy-fixture",
                rootPath: storageRoot.path,
                endpoint: nil
            ),
            encryption: EncryptionDescriptor(
                mode: .legacyAes128Cbc,
                kdf: .pbkdf2Sha256,
                salt: salt.base64EncodedStringValue,
                iterations: TestResources.legacyIterations,
                wrappedKey: wrappedKey.base64EncodedStringValue
            ),
            chunks: zip(TestResources.legacyChunkURLs.indices, TestResources.legacyChunkURLs).map { index, url in
                let ciphertext = try! Data(contentsOf: url)
                return ChunkDescriptor(
                    index: index,
                    objectKey: url.lastPathComponent,
                    offset: index * (plaintext.count / 2),
                    plaintextSize: plaintext.count / 2,
                    ciphertextSize: ciphertext.count,
                    sha256: try! ChunkCrypter.sha256Hex(of: ciphertext),
                    nonce: nil,
                    iv: TestResources.legacyIVs[index].base64EncodedStringValue
                )
            }
        )

        let tempRoot = TestResources.temporaryDirectory(named: "fragseal-legacy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let manifestPath = FilePath(tempRoot.appendingPathComponent("legacy.toml").path)
        let outputPath = FilePath(tempRoot.appendingPathComponent("restored.bin").path)
        try TomlManifestCodec.write(manifest, to: manifestPath)

        let downloader = BackupDownloader()
        try await downloader.download(
            manifestPath: manifestPath,
            output: outputPath,
            passphrase: TestResources.legacyPassphrase
        )

        let restored = try Data(contentsOf: URL(fileURLWithPath: outputPath.string))
        #expect(restored == plaintext)
    }
}
