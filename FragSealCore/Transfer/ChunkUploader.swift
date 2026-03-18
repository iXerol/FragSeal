//
//  ChunkUploader.swift
//  FragSealCore
//

import Foundation

actor ChunkUploader {
    struct Request: Sendable {
        let index: Int
        let offset: Int
        let objectKey: String
        let plaintext: Data
    }

    private let storage: any ObjectStorage
    private let crypter: ChunkCrypter?
    private let mode: EncryptionMode

    init(storage: any ObjectStorage, mode: EncryptionMode, crypter: ChunkCrypter? = nil) {
        self.storage = storage
        self.mode = mode
        self.crypter = crypter
    }

    func upload(_ requests: [Request], concurrencyLimit: Int = 4) async throws -> [ChunkDescriptor] {
        var descriptors = Array<ChunkDescriptor?>(repeating: nil, count: requests.count)
        let pending = requests.enumerated()
        var iterator = pending.makeIterator()

        func uploadChunk(request: Request,
                         storage: any ObjectStorage,
                         mode: EncryptionMode,
                         crypter: ChunkCrypter) async throws -> ChunkDescriptor {
            let nonceOrIV = try ChunkCrypter.randomNonceOrIV(for: mode)
            let ciphertext = try await crypter.encrypt(plaintext: request.plaintext, nonceOrIV: nonceOrIV)
            try await retry("upload \(request.objectKey)") {
                try await storage.putObject(key: request.objectKey, data: ciphertext)
            } when: { error, attempt in
                storage.retryDirective(for: error, attempt: attempt)
            }
            let encodedNonceOrIV = nonceOrIV.base64EncodedStringValue
            return ChunkDescriptor(
                index: request.index,
                objectKey: request.objectKey,
                offset: request.offset,
                plaintextSize: request.plaintext.count,
                ciphertextSize: ciphertext.count,
                sha256: try ChunkCrypter.sha256Hex(of: ciphertext),
                nonce: mode == .legacyAes128Cbc ? nil : encodedNonceOrIV,
                iv: mode == .legacyAes128Cbc ? encodedNonceOrIV : nil
            )
        }

        func uploadPlaintextChunk(request: Request,
                                  storage: any ObjectStorage) async throws -> ChunkDescriptor {
            try await retry("upload \(request.objectKey)") {
                try await storage.putObject(key: request.objectKey, data: request.plaintext)
            } when: { error, attempt in
                storage.retryDirective(for: error, attempt: attempt)
            }

            return ChunkDescriptor(
                index: request.index,
                objectKey: request.objectKey,
                offset: request.offset,
                plaintextSize: request.plaintext.count,
                ciphertextSize: request.plaintext.count,
                sha256: "",
                nonce: nil,
                iv: nil
            )
        }

        try await withThrowingTaskGroup(of: (Int, ChunkDescriptor).self) { group in
            var inFlight = 0
            while inFlight < concurrencyLimit, let (offset, request) = iterator.next() {
                inFlight += 1
                group.addTask { [storage, mode, crypter] in
                    if mode == .none {
                        return (offset, try await uploadPlaintextChunk(request: request, storage: storage))
                    }
                    guard let crypter else {
                        throw ChunkCrypter.Error.unsupportedMode(mode)
                    }
                    return (offset, try await uploadChunk(request: request, storage: storage, mode: mode, crypter: crypter))
                }
            }

            while let (offset, descriptor) = try await group.next() {
                descriptors[offset] = descriptor
                if let (nextOffset, nextRequest) = iterator.next() {
                    group.addTask { [storage, mode, crypter] in
                        if mode == .none {
                            return (nextOffset, try await uploadPlaintextChunk(request: nextRequest, storage: storage))
                        }
                        guard let crypter else {
                            throw ChunkCrypter.Error.unsupportedMode(mode)
                        }
                        return (nextOffset, try await uploadChunk(
                            request: nextRequest,
                            storage: storage,
                            mode: mode,
                            crypter: crypter
                        ))
                    }
                }
            }
        }

        return try descriptors.enumerated().map { offset, descriptor in
            guard let descriptor else {
                throw ChunkTransferError.missingDescriptor(offset)
            }
            return descriptor
        }
    }
}

enum ChunkTransferError: Error {
    case missingDescriptor(Int)
}
