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
    private let crypter: ChunkCrypter
    init(storage: any ObjectStorage, crypter: ChunkCrypter) {
        self.storage = storage
        self.crypter = crypter
    }

    func upload(_ requests: [Request], concurrencyLimit: Int = 4) async throws -> [ChunkDescriptor] {
        var descriptors = Array<ChunkDescriptor?>(repeating: nil, count: requests.count)
        let pending = requests.enumerated()
        var iterator = pending.makeIterator()

        func uploadChunk(request: Request,
                         storage: any ObjectStorage,
                         crypter: ChunkCrypter) async throws -> ChunkDescriptor {
            let nonceOrIV = try ChunkCrypter.randomNonceOrIV(for: crypter.mode)
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
                nonce: crypter.mode == .legacyAes128Cbc ? nil : encodedNonceOrIV,
                iv: crypter.mode == .legacyAes128Cbc ? encodedNonceOrIV : nil
            )
        }

        try await withThrowingTaskGroup(of: (Int, ChunkDescriptor).self) { group in
            var inFlight = 0
            while inFlight < concurrencyLimit, let (offset, request) = iterator.next() {
                inFlight += 1
                group.addTask { [storage, crypter] in
                    return (offset, try await uploadChunk(request: request, storage: storage, crypter: crypter))
                }
            }

            while let (offset, descriptor) = try await group.next() {
                descriptors[offset] = descriptor
                if let (nextOffset, nextRequest) = iterator.next() {
                    group.addTask { [storage, crypter] in
                        return (nextOffset, try await uploadChunk(request: nextRequest, storage: storage, crypter: crypter))
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
