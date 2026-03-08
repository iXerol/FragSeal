//
//  FragSealCryptoOverlay.swift
//  FragSealCrypto
//

import Foundation

// Additional Swift conveniences can live here.

public extension LegacyAes128CbcCrypter {
    enum Error: Swift.Error {
        case decryptFailed
    }

    func decrypt(ivSpan: consuming Span<UInt8>, dataSpan: consuming Span<UInt8>) async throws (Error) -> Data {
        var plaintext = Data(count: dataSpan.count)
        let destinationSpan = plaintext.mutableSpan
        let decryptedCount = decrypt(
            iv: .init(ivSpan),
            ciphertext: .init(dataSpan),
            destination: .init(destinationSpan)
        )
            .value
            .map { Int($0) }

        guard let decryptedCount,
              0...plaintext.count ~= decryptedCount else {
            throw .decryptFailed
        }

        plaintext.removeLast(plaintext.count - decryptedCount)
        return plaintext
    }
}

public extension Aes256GcmCrypter {
    enum Error: Swift.Error {
        case encryptFailed
        case decryptFailed
    }

    func encrypt(nonceSpan: consuming Span<UInt8>, dataSpan: consuming Span<UInt8>) async throws(Error) -> Data {
        var ciphertext = Data(count: dataSpan.count + Self.tagSize)
        let encryptedCount = encrypt(
            nonce: .init(nonceSpan),
            plaintext: .init(dataSpan),
            destination: .init(ciphertext.mutableSpan)
        )
            .value
            .map { Int($0) }

        guard let encryptedCount,
              0...ciphertext.count ~= encryptedCount else {
            throw .encryptFailed
        }

        ciphertext.removeLast(ciphertext.count - encryptedCount)
        return ciphertext
    }

    func decrypt(nonceSpan: consuming Span<UInt8>, dataSpan: consuming Span<UInt8>) async throws(Error) -> Data {
        var plaintext = Data(count: dataSpan.count)
        let decryptedCount = decrypt(
            nonce: .init(nonceSpan),
            ciphertext: .init(dataSpan),
            destination: .init(plaintext.mutableSpan)
        )
            .value
            .map { Int($0) }

        guard let decryptedCount,
              0...plaintext.count ~= decryptedCount else {
            throw .decryptFailed
        }

        plaintext.removeLast(plaintext.count - decryptedCount)
        return plaintext
    }
}

public extension ChaCha20Poly1305Crypter {
    enum Error: Swift.Error {
        case encryptFailed
        case decryptFailed
    }

    func encrypt(nonceSpan: consuming Span<UInt8>, dataSpan: consuming Span<UInt8>) async throws(Error) -> Data {
        var ciphertext = Data(count: dataSpan.count + Self.tagSize)
        let encryptedCount = encrypt(
            nonce: .init(nonceSpan),
            plaintext: .init(dataSpan),
            destination: .init(ciphertext.mutableSpan)
        )
            .value
            .map { Int($0) }

        guard let encryptedCount,
              0...ciphertext.count ~= encryptedCount else {
            throw .encryptFailed
        }

        ciphertext.removeLast(ciphertext.count - encryptedCount)
        return ciphertext
    }

    func decrypt(nonceSpan: consuming Span<UInt8>, dataSpan: consuming Span<UInt8>) async throws(Error) -> Data {
        var plaintext = Data(count: dataSpan.count)
        let decryptedCount = decrypt(
            nonce: .init(nonceSpan),
            ciphertext: .init(dataSpan),
            destination: .init(plaintext.mutableSpan)
        )
            .value
            .map { Int($0) }

        guard let decryptedCount,
              0...plaintext.count ~= decryptedCount else {
            throw .decryptFailed
        }

        plaintext.removeLast(plaintext.count - decryptedCount)
        return plaintext
    }
}

public extension PBKDF2KeyDeriver {
    enum Error: Swift.Error {
        case deriveFailed
    }

    static func deriveSHA256(password: Data,
                             salt: Data,
                             iterations: UInt32,
                             keySize: Int = Self.defaultKeySize) throws(Error) -> Data {
        var derived = Data(count: keySize)
        let derivedCount = deriveSHA256(
            password: .init(password.span),
            salt: .init(salt.span),
            iterations: iterations,
            destination: .init(derived.mutableSpan)
        )
            .value
            .map { Int($0) }

        guard let derivedCount,
              derivedCount == keySize else {
            throw .deriveFailed
        }

        return derived
    }
}

public extension SHA256Hasher {
    enum Error: Swift.Error {
        case hashFailed
    }

    static func hash(data: Data) throws(Error) -> Data {
        var digest = Data(count: Self.digestSize)
        let digestCount = hash(
            data: .init(data.span),
            destination: .init(digest.mutableSpan)
        )
            .value
            .map { Int($0) }

        guard let digestCount,
              digestCount == Self.digestSize else {
            throw .hashFailed
        }

        return digest
    }
}

public extension SecureRandom {
    enum Error: Swift.Error {
        case generationFailed
    }

    static func data(count: Int) throws(Error) -> Data {
        var data = Data(count: count)
        guard fill(destination: .init(data.mutableSpan)) else {
            throw .generationFailed
        }
        return data
    }
}
