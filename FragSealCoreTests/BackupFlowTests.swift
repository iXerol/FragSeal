//
//  BackupFlowTests.swift
//  FragSealCoreTests
//

import Foundation
import System
import Testing
@testable import FragSealCore

@Suite
struct BackupFlowTests {
    @Test
    func uploadAndDownloadRoundTripWithAESGCM() async throws {
        try await assertRoundTrip(algorithm: .aes256Gcm)
    }

    @Test
    func uploadAndDownloadRoundTripWithChaCha20Poly1305() async throws {
        try await assertRoundTrip(algorithm: .chacha20Poly1305)
    }

    @Test
    func downloadFailsForWrongPassphrase() async throws {
        let tempRoot = TestResources.temporaryDirectory(named: "fragseal-wrong-passphrase-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let inputURL = tempRoot.appendingPathComponent("input.bin")
        let manifestPath = FilePath(tempRoot.appendingPathComponent("manifest.toml").path)
        let outputPath = FilePath(tempRoot.appendingPathComponent("output.bin").path)
        let storageURI = URL(fileURLWithPath: tempRoot.appendingPathComponent("storage").path)
        let inputData = Data((0 ..< 4096).map { UInt8($0 % 251) })
        try inputData.write(to: inputURL)

        let uploader = BackupUploader()
        _ = try await uploader.upload(
            input: FilePath(inputURL.path),
            manifestPath: manifestPath,
            storageURI: storageURI,
            algorithm: .aes256Gcm,
            chunkSize: 1024,
            passphrase: "correct-passphrase"
        )

        let downloader = BackupDownloader()
        await #expect(throws: Error.self) {
            try await downloader.download(
                manifestPath: manifestPath,
                output: outputPath,
                passphrase: "wrong-passphrase"
            )
        }
    }

    @Test
    func downloadFailsForCorruptedChunk() async throws {
        let tempRoot = TestResources.temporaryDirectory(named: "fragseal-corrupt-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let inputURL = tempRoot.appendingPathComponent("input.bin")
        let manifestPath = FilePath(tempRoot.appendingPathComponent("manifest.toml").path)
        let outputPath = FilePath(tempRoot.appendingPathComponent("output.bin").path)
        let storageURI = URL(fileURLWithPath: tempRoot.appendingPathComponent("storage").path)
        let inputData = Data((0 ..< 2048).map { UInt8(($0 * 7) % 251) })
        try inputData.write(to: inputURL)

        let uploader = BackupUploader()
        let manifest = try await uploader.upload(
            input: FilePath(inputURL.path),
            manifestPath: manifestPath,
            storageURI: storageURI,
            algorithm: .aes256Gcm,
            chunkSize: 512,
            passphrase: "fragseal-passphrase"
        )

        let firstChunk = URL(fileURLWithPath: tempRoot.appendingPathComponent("storage").path)
            .appendingPathComponent(manifest.chunks[0].objectKeyValue)
        try Data("broken".utf8).write(to: firstChunk)

        let downloader = BackupDownloader()
        await #expect(throws: Error.self) {
            try await downloader.download(
                manifestPath: manifestPath,
                output: outputPath,
                passphrase: "fragseal-passphrase"
            )
        }
    }

    @Test
    func chunkUploaderAndDownloaderWorkWithMockObjectStorage() async throws {
        let mockStorage = MockObjectStorage()
        let key = Data(repeating: 0x33, count: EncryptionMode.aes256Gcm.keySize)
        let crypter = try ChunkCrypter(mode: .aes256Gcm, key: key)
        let uploader = ChunkUploader(storage: mockStorage, crypter: crypter)
        let chunks = [
            ChunkUploader.Request(index: 0, offset: 0, objectKey: "chunks/0.bin", plaintext: Data("hello ".utf8)),
            ChunkUploader.Request(index: 1, offset: 6, objectKey: "chunks/1.bin", plaintext: Data("fragseal".utf8)),
        ]

        let descriptors = try await uploader.upload(chunks, concurrencyLimit: 2)
        let outputDirectory = TestResources.temporaryDirectory(named: "fragseal-mock-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let downloader = ChunkDownloader(storage: mockStorage, crypter: crypter)
        let outputPath = FilePath(outputDirectory.appendingPathComponent("output.bin").path)
        try await downloader.download(chunks: descriptors, to: outputPath, concurrencyLimit: 2)
        let restored = try Data(contentsOf: URL(fileURLWithPath: outputPath.string))
        #expect(restored == Data("hello fragseal".utf8))
    }

    @Test
    func chunkTransferRetriesTransientStorageFailures() async throws {
        let mockStorage = FlakyRetryingMockObjectStorage(
            putFailuresRemaining: [
                "chunks/0.bin": 1,
                "chunks/1.bin": 2,
            ],
            getFailuresRemaining: [
                "chunks/0.bin": 1,
                "chunks/1.bin": 1,
            ]
        )
        let key = Data(repeating: 0x44, count: EncryptionMode.aes256Gcm.keySize)
        let crypter = try ChunkCrypter(mode: .aes256Gcm, key: key)
        let uploader = ChunkUploader(storage: mockStorage, crypter: crypter)
        let chunks = [
            ChunkUploader.Request(index: 0, offset: 0, objectKey: "chunks/0.bin", plaintext: Data("hello ".utf8)),
            ChunkUploader.Request(index: 1, offset: 6, objectKey: "chunks/1.bin", plaintext: Data("retry".utf8)),
        ]

        let descriptors = try await uploader.upload(chunks, concurrencyLimit: 2)
        let outputDirectory = TestResources.temporaryDirectory(named: "fragseal-retry-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let downloader = ChunkDownloader(storage: mockStorage, crypter: crypter)
        let outputPath = FilePath(outputDirectory.appendingPathComponent("output.bin").path)
        try await downloader.download(chunks: descriptors, to: outputPath, concurrencyLimit: 2)

        let restored = try Data(contentsOf: URL(fileURLWithPath: outputPath.string))
        #expect(restored == Data("hello retry".utf8))
    }

    private func assertRoundTrip(algorithm: EncryptionMode) async throws {
        let tempRoot = TestResources.temporaryDirectory(named: "fragseal-roundtrip-\(algorithm.rawValue)-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let inputURL = tempRoot.appendingPathComponent("input.bin")
        let manifestPath = FilePath(tempRoot.appendingPathComponent("manifest.toml").path)
        let outputPath = FilePath(tempRoot.appendingPathComponent("output.bin").path)
        let storageRoot = tempRoot.appendingPathComponent("storage")
        let storageURI = URL(fileURLWithPath: storageRoot.path)
        let passphrase = "fragseal-passphrase"
        let inputData = Data((0 ..< 8192).map { UInt8(($0 * 13) % 251) })
        try inputData.write(to: inputURL)

        let uploader = BackupUploader()
        let manifest = try await uploader.upload(
            input: FilePath(inputURL.path),
            manifestPath: manifestPath,
            storageURI: storageURI,
            algorithm: algorithm,
            chunkSize: 1024,
            passphrase: passphrase
        )

        let downloader = BackupDownloader()
        try await downloader.download(
            manifestPath: manifestPath,
            output: outputPath,
            passphrase: passphrase
        )

        let restored = try Data(contentsOf: URL(fileURLWithPath: outputPath.string))
        #expect(restored == inputData)
        #expect(FileManager.default.fileExists(atPath: manifestPath.string))
        #expect(FileManager.default.fileExists(atPath: try manifest.storage.resolvedManifestPath().string))
    }
}

private actor MockObjectStorage: ObjectStorage {
    private var objects: [String: Data] = [:]

    func getObject(key: String) async throws -> Data {
        guard let data = objects[key] else {
            throw MockStorageError.missingObject(key)
        }
        return data
    }

    func putObject(key: String, data: Data) async throws {
        objects[key] = data
    }
}

private enum MockStorageError: Error {
    case missingObject(String)
    case transient(String)
}

private actor FlakyRetryingMockObjectStorage: ObjectStorage {
    private var objects: [String: Data] = [:]
    private var putFailuresRemaining: [String: Int]
    private var getFailuresRemaining: [String: Int]

    init(putFailuresRemaining: [String: Int], getFailuresRemaining: [String: Int]) {
        self.putFailuresRemaining = putFailuresRemaining
        self.getFailuresRemaining = getFailuresRemaining
    }

    func getObject(key: String) async throws -> Data {
        if let remaining = getFailuresRemaining[key], remaining > 0 {
            getFailuresRemaining[key] = remaining - 1
            throw MockStorageError.transient(key)
        }
        guard let data = objects[key] else {
            throw MockStorageError.missingObject(key)
        }
        return data
    }

    func putObject(key: String, data: Data) async throws {
        if let remaining = putFailuresRemaining[key], remaining > 0 {
            putFailuresRemaining[key] = remaining - 1
            throw MockStorageError.transient(key)
        }
        objects[key] = data
    }

    nonisolated func retryDirective(for error: any Error, attempt: Int) -> TransferRetryDirective {
        guard case MockStorageError.transient = error, attempt < 4 else {
            return .stop
        }
        return .retry(after: .zero)
    }
}
