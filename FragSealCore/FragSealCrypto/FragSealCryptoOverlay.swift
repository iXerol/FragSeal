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
        var destinationSpan = plaintext.mutableSpan
        let decryptedCount = decrypt(
            iv: ivSpan,
            ciphertext: dataSpan,
            destination: &destinationSpan
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
        var destinationSpan = ciphertext.mutableSpan
        let encryptedCount = encrypt(
            nonce: nonceSpan,
            plaintext: dataSpan,
            destination: &destinationSpan
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
        var destinationSpan = plaintext.mutableSpan
        let decryptedCount = decrypt(
            nonce: nonceSpan,
            ciphertext: dataSpan,
            destination: &destinationSpan
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
        var destinationSpan = ciphertext.mutableSpan
        let encryptedCount = encrypt(
            nonce: nonceSpan,
            plaintext: dataSpan,
            destination: &destinationSpan
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
        var destinationSpan = plaintext.mutableSpan
        let decryptedCount = decrypt(
            nonce: nonceSpan,
            ciphertext: dataSpan,
            destination: &destinationSpan
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
        var destinationSpan = derived.mutableSpan
        let derivedCount = deriveSHA256(
            password: password.span,
            salt: salt.span,
            iterations: iterations,
            destination: &destinationSpan
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
        var destinationSpan = digest.mutableSpan
        let digestCount = hash(
            data: data.span,
            destination: &destinationSpan
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
        var destination = data.mutableSpan
        guard fill(destination: &destination) else {
            throw .generationFailed
        }
        return data
    }
}

public enum CryptoSupport {
    public static var aes256Gcm: Bool {
        CryptoCapabilities.supportsAes256Gcm()
    }

    public static var chacha20Poly1305: Bool {
        CryptoCapabilities.supportsChaCha20Poly1305()
    }

    public static var legacyAes128Cbc: Bool {
        CryptoCapabilities.supportsLegacyAes128Cbc()
    }
}
