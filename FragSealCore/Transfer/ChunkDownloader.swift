//
//  ChunkDownloader.swift
//  FragSealCore
//

import Foundation
import System
import FragSealFileSystem

actor ChunkDownloader {
    private let storage: any ObjectStorage
    private let crypter: ChunkCrypter
    init(storage: any ObjectStorage, crypter: ChunkCrypter) {
        self.storage = storage
        self.crypter = crypter
    }

    func download(chunks: some Sequence<ChunkDescriptor>,
                  to destination: FilePath,
                  downloadSession: String = UUID().uuidString,
                  concurrencyLimit: Int = 4,
                  removeDestinationFileIfExists: Bool = true) async throws {
        let chunks = Array(chunks)
        if destination.exists() {
            if removeDestinationFileIfExists {
                try destination.remove()
            } else {
                throw ChunkDownloaderError.outputExists
            }
        }

        let parentDirectory = destination.removingLastComponent()
        try parentDirectory.createDirectory(recursive: true)
        let sessionDirectory = parentDirectory.appending(downloadSession)
        try sessionDirectory.createDirectory(recursive: true)

        let destinationWriter = try FileWriter(path: destination, mode: .createNew)
        var tasks: [Task<FilePath, Error>] = []
        let concurrencyCount = min(concurrencyLimit, chunks.count)
        var nextIndex = 0

        func makeTask(index: Int) -> Task<FilePath, Error> {
            let chunk = chunks[index]
            return Task { [storage, crypter] in
                let ciphertext = try await retry("download \(chunk.objectKeyValue)") {
                    try await storage.getObject(key: chunk.objectKeyValue)
                } when: { error, attempt in
                        storage.retryDirective(for: error, attempt: attempt)
                    }
                let expectedHash = try ChunkCrypter.sha256Hex(of: ciphertext)
                guard expectedHash == chunk.sha256Value else {
                    throw ChunkDownloaderError.hashMismatch(index)
                }

                let plaintext = try await crypter.decrypt(
                    ciphertext: ciphertext,
                    nonceOrIV: try chunk.nonceOrIV(for: crypter.mode)
                )
                let outputPath = sessionDirectory.appending("\(chunk.index).bin")
                let writer = try FileWriter(path: outputPath, mode: .truncate)
                try writer.append(plaintext)
                return outputPath
            }
        }

        while nextIndex < concurrencyCount {
            tasks.append(makeTask(index: nextIndex))
            nextIndex += 1
        }

        while !tasks.isEmpty {
            let task = tasks.removeFirst()
            let filePath = try await task.value
            let input = try FileDescriptor.open(filePath, .readOnly)
            _ = try destinationWriter.append(from: input)
            try filePath.remove()

            if nextIndex < chunks.count {
                tasks.append(makeTask(index: nextIndex))
                nextIndex += 1
            }
        }

        if try await sessionDirectory.isEmptyDirectory() {
            try sessionDirectory.remove()
        }
        print("Downloaded \(chunks.count) chunks to \(destination.string)")
    }
}

enum ChunkDownloaderError: Error {
    case outputExists
    case hashMismatch(Int)
}
