//
//  RuntimeAvailabilityTests.swift
//  FragSealCoreTests
//

import Foundation
import System
import Testing
@testable import FragSealCore

@Suite
struct RuntimeAvailabilityTests {
    @Test
    func modernAlgorithmsAreUnavailableWhenOpenSSLRuntimeIsForcedOff() {
        guard isRuntimeForcedUnavailable else { return }
        #expect(!ChunkCrypter.supportsEncryption(.aes256Gcm))
        #expect(!ChunkCrypter.supportsEncryption(.chacha20Poly1305))
        #expect(!ChunkCrypter.supportsDecryption(.aes256Gcm))
        #expect(!ChunkCrypter.supportsDecryption(.chacha20Poly1305))
    }

    @Test
    func modernUploadFailsWhenOpenSSLRuntimeIsForcedOff() async throws {
        guard isRuntimeForcedUnavailable else { return }
        let tempRoot = TestResources.temporaryDirectory(named: "fragseal-runtime-off-upload-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let inputURL = tempRoot.appendingPathComponent("input.bin")
        try Data("runtime unavailable".utf8).write(to: inputURL)
        let manifestPath = FilePath(tempRoot.appendingPathComponent("manifest.toml").path)
        let storageURI = URL(fileURLWithPath: tempRoot.appendingPathComponent("storage").path)
        let uploader = BackupUploader()

        try await assertCryptoUnavailableUpload(
            uploader: uploader,
            inputURL: inputURL,
            manifestPath: manifestPath,
            storageURI: storageURI,
            mode: .aes256Gcm
        )
        try await assertCryptoUnavailableUpload(
            uploader: uploader,
            inputURL: inputURL,
            manifestPath: manifestPath,
            storageURI: storageURI,
            mode: .chacha20Poly1305
        )
    }

    @Test
    func encryptedDownloadFailsWhenOpenSSLRuntimeIsForcedOff() async throws {
        guard isRuntimeForcedUnavailable else { return }
        let tempRoot = TestResources.temporaryDirectory(named: "fragseal-runtime-off-download-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let manifestPath = FilePath(tempRoot.appendingPathComponent("manifest.toml").path)
        let outputPath = FilePath(tempRoot.appendingPathComponent("output.bin").path)
        let storageRoot = tempRoot.appendingPathComponent("storage")
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        let manifest = dummyEncryptedManifest(mode: .aes256Gcm, storageRoot: storageRoot.path)
        try TomlManifestCodec.write(manifest, to: manifestPath)

        let downloader = BackupDownloader()
        do {
            try await downloader.download(
                manifestPath: manifestPath,
                output: outputPath,
                passphrase: "fragseal-passphrase"
            )
            Issue.record("Expected encrypted download to fail when OpenSSL runtime is unavailable.")
        } catch let error as BackupDownloader.Error {
            guard case .cryptoUnavailable(let mode) = error else {
                Issue.record("Expected cryptoUnavailable, got: \(error)")
                return
            }
            #expect(mode == .aes256Gcm)
        }
    }

    @Test
    func legacySupportMatchesPlatformWhenOpenSSLRuntimeIsForcedOff() {
        guard isRuntimeForcedUnavailable else { return }
#if os(macOS)
        #expect(ChunkCrypter.supportsDecryption(.legacyAes128Cbc))
#else
        #expect(!ChunkCrypter.supportsDecryption(.legacyAes128Cbc))
#endif
    }

    @Test
    func legacyRestoreSucceedsOnMacOSWhenOpenSSLRuntimeIsForcedOff() async throws {
        guard isRuntimeForcedUnavailable else { return }
#if os(macOS)
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
                id: "legacy-runtime-off",
                sourceName: "legacy_plaintext.bin",
                createdAt: "2026-03-19T00:00:00Z",
                chunkSize: plaintext.count / 2,
                originalSize: plaintext.count,
                originalSha256: try ChunkCrypter.sha256Hex(of: plaintext)
            ),
            storage: StorageDescriptor(
                backend: .local,
                bucket: nil,
                region: nil,
                prefix: "legacy-runtime-off",
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

        let tempRoot = TestResources.temporaryDirectory(named: "fragseal-runtime-off-legacy-macos-\(UUID().uuidString)")
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
#endif
    }

    @Test
    func legacyDownloadFailsOnLinuxWhenOpenSSLRuntimeIsForcedOff() async throws {
        guard isRuntimeForcedUnavailable else { return }
#if os(Linux)
        let tempRoot = TestResources.temporaryDirectory(named: "fragseal-runtime-off-legacy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let manifestPath = FilePath(tempRoot.appendingPathComponent("legacy.toml").path)
        let outputPath = FilePath(tempRoot.appendingPathComponent("restored.bin").path)
        let storageRoot = tempRoot.appendingPathComponent("storage")
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        let manifest = dummyEncryptedManifest(mode: .legacyAes128Cbc, storageRoot: storageRoot.path)
        try TomlManifestCodec.write(manifest, to: manifestPath)

        let downloader = BackupDownloader()
        do {
            try await downloader.download(
                manifestPath: manifestPath,
                output: outputPath,
                passphrase: "fragseal-passphrase"
            )
            Issue.record("Expected legacy download to fail on Linux without OpenSSL runtime.")
        } catch let error as BackupDownloader.Error {
            guard case .cryptoUnavailable(let mode) = error else {
                Issue.record("Expected cryptoUnavailable, got: \(error)")
                return
            }
            #expect(mode == .legacyAes128Cbc)
        }
#endif
    }

    private var isRuntimeForcedUnavailable: Bool {
        let value = ProcessInfo.processInfo.environment["FRAGSEAL_OPENSSL_FORCE_UNAVAILABLE"] ?? ""
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !normalized.isEmpty && normalized != "0" && normalized != "false"
    }

    private func assertCryptoUnavailableUpload(uploader: BackupUploader,
                                               inputURL: URL,
                                               manifestPath: FilePath,
                                               storageURI: URL,
                                               mode: EncryptionMode) async throws {
        do {
            _ = try await uploader.upload(
                input: FilePath(inputURL.path),
                manifestPath: manifestPath,
                storageURI: storageURI,
                algorithm: mode,
                chunkSize: 512,
                passphrase: "fragseal-passphrase"
            )
            Issue.record("Expected upload with \(mode.rawValue) to fail when runtime crypto is unavailable.")
        } catch let error as BackupUploader.Error {
            guard case .cryptoUnavailable(let unavailableMode) = error else {
                Issue.record("Expected cryptoUnavailable, got: \(error)")
                return
            }
            #expect(unavailableMode == mode)
        }
    }

    private func dummyEncryptedManifest(mode: EncryptionMode, storageRoot: String) -> BackupManifest {
        let nonce = Data(repeating: 0x11, count: mode == .legacyAes128Cbc ? 16 : 12).base64EncodedString()
        return BackupManifest(
            backup: BackupDescriptor(
                id: "runtime-off-\(mode.rawValue)",
                sourceName: "archive.bin",
                createdAt: "2026-03-19T00:00:00Z",
                chunkSize: 1024,
                originalSize: 1024,
                originalSha256: String(repeating: "a", count: 64)
            ),
            storage: StorageDescriptor(
                backend: .local,
                bucket: nil,
                region: nil,
                prefix: "fragseal/runtime-off",
                rootPath: storageRoot,
                endpoint: nil
            ),
            encryption: EncryptionDescriptor(
                mode: mode,
                kdf: .pbkdf2Sha256,
                salt: Data([0x01, 0x02, 0x03]).base64EncodedString(),
                iterations: 600_000,
                wrappedKey: Data([0x04, 0x05, 0x06, 0x07]).base64EncodedString()
            ),
            chunks: [
                ChunkDescriptor(
                    index: 0,
                    objectKey: "fragseal/runtime-off/chunks/00000000.bin",
                    offset: 0,
                    plaintextSize: 1024,
                    ciphertextSize: 1040,
                    sha256: String(repeating: "b", count: 64),
                    nonce: mode == .legacyAes128Cbc ? nil : nonce,
                    iv: mode == .legacyAes128Cbc ? nonce : nil
                ),
            ]
        )
    }
}
