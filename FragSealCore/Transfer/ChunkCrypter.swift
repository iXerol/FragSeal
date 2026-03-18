//
//  ChunkCrypter.swift
//  FragSealCore
//

private import FragSealCrypto
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

struct ChunkCrypter: Sendable {
    enum Error: Swift.Error {
        case unsupportedMode(EncryptionMode)
        case invalidKeyLength(EncryptionMode)
        case invalidNonceLength(EncryptionMode)
        case cryptoUnavailable(EncryptionMode)
        case encryptFailed(EncryptionMode)
        case decryptFailed(EncryptionMode)
    }

    let mode: EncryptionMode
    private let key: Data

    init(mode: EncryptionMode, key: Data) throws {
        guard key.count == mode.keySize else {
            throw Error.invalidKeyLength(mode)
        }
        self.mode = mode
        self.key = key
    }

    func encrypt(plaintext: Data, nonceOrIV: Data) async throws -> Data {
        guard nonceOrIV.count == mode.nonceSize else {
            throw Error.invalidNonceLength(mode)
        }

        switch mode {
        case .none:
            return plaintext
        case .aes256Gcm:
            let crypter = Aes256GcmCrypter(keySpan: key.span)
            do {
                return try await crypter.encrypt(nonceSpan: nonceOrIV.span, dataSpan: plaintext.span)
            } catch {
                throw Error.encryptFailed(mode)
            }
        case .chacha20Poly1305:
            let crypter = ChaCha20Poly1305Crypter(keySpan: key.span)
            do {
                return try await crypter.encrypt(nonceSpan: nonceOrIV.span, dataSpan: plaintext.span)
            } catch {
                throw Error.encryptFailed(mode)
            }
        case .legacyAes128Cbc:
            throw Error.unsupportedMode(mode)
        @unknown default:
            throw Error.unsupportedMode(mode)
        }
    }

    func decrypt(ciphertext: Data, nonceOrIV: Data) async throws -> Data {
        guard nonceOrIV.count == mode.nonceSize else {
            throw Error.invalidNonceLength(mode)
        }

        switch mode {
        case .none:
            return ciphertext
        case .aes256Gcm:
            let crypter = Aes256GcmCrypter(keySpan: key.span)
            do {
                return try await crypter.decrypt(nonceSpan: nonceOrIV.span, dataSpan: ciphertext.span)
            } catch {
                throw Error.decryptFailed(mode)
            }
        case .chacha20Poly1305:
            let crypter = ChaCha20Poly1305Crypter(keySpan: key.span)
            do {
                return try await crypter.decrypt(nonceSpan: nonceOrIV.span, dataSpan: ciphertext.span)
            } catch {
                throw Error.decryptFailed(mode)
            }
        case .legacyAes128Cbc:
            let crypter = LegacyAes128CbcCrypter(keySpan: key.span)
            do {
                return try await crypter.decrypt(ivSpan: nonceOrIV.span, dataSpan: ciphertext.span)
            } catch {
                throw Error.decryptFailed(mode)
            }
        @unknown default:
            throw Error.decryptFailed(mode)
        }
    }

    static func randomKey(for mode: EncryptionMode) throws -> Data {
        guard mode != .none else {
            return Data()
        }
        return try randomBytes(count: mode.keySize)
    }

    static func randomNonceOrIV(for mode: EncryptionMode) throws -> Data {
        guard mode != .none else {
            return Data()
        }
        return try randomBytes(count: mode.nonceSize)
    }

    static func randomBytes(count: Int) throws -> Data {
        try SecureRandom.data(count: count)
    }

    static func sha256Hex(of data: Data) throws -> String {
        try SHA256Hasher.hash(data: data).hexString
    }

    static func wrapKey(_ dataKey: Data,
                        with wrappingKey: Data) async throws -> Data {
        let nonce = try randomBytes(count: Aes256GcmCrypter.nonceSize)
        if CryptoSupport.aes256Gcm {
            let crypter = Aes256GcmCrypter(keySpan: wrappingKey.span)
            let ciphertext = try await crypter.encrypt(nonceSpan: nonce.span, dataSpan: dataKey.span)
            return nonce + ciphertext
        }

#if canImport(CryptoKit)
        let symmetricKey = SymmetricKey(data: wrappingKey)
        let cryptoNonce = try AES.GCM.Nonce(data: nonce)
        let sealed = try AES.GCM.seal(dataKey, using: symmetricKey, nonce: cryptoNonce)
        return nonce + sealed.ciphertext + sealed.tag
#else
        throw Error.cryptoUnavailable(.aes256Gcm)
#endif
    }

    static func unwrapKey(_ wrappedKey: Data,
                          with wrappingKey: Data) async throws -> Data {
        let nonceSize = Aes256GcmCrypter.nonceSize
        guard wrappedKey.count >= nonceSize + Aes256GcmCrypter.tagSize else {
            throw Error.decryptFailed(.aes256Gcm)
        }
        let nonce = wrappedKey.prefix(nonceSize)
        let ciphertext = wrappedKey.dropFirst(nonceSize)
        if CryptoSupport.aes256Gcm {
            let crypter = Aes256GcmCrypter(keySpan: wrappingKey.span)
            do {
                return try await crypter.decrypt(nonceSpan: nonce.span, dataSpan: ciphertext.span)
            } catch {
                throw Error.decryptFailed(.aes256Gcm)
            }
        }

#if canImport(CryptoKit)
        let ciphertextData = Data(ciphertext.dropLast(Aes256GcmCrypter.tagSize))
        let tag = Data(ciphertext.suffix(Aes256GcmCrypter.tagSize))
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: .init(data: nonce),
                ciphertext: ciphertextData,
                tag: tag
            )
            return try AES.GCM.open(sealedBox, using: SymmetricKey(data: wrappingKey))
        } catch {
            throw Error.decryptFailed(.aes256Gcm)
        }
#else
        throw Error.cryptoUnavailable(.aes256Gcm)
#endif
    }

    static func deriveWrappingKey(passphrase: String,
                                  salt: Data,
                                  iterations: UInt32) throws -> Data {
        try PBKDF2KeyDeriver.deriveSHA256(password: Data(passphrase.utf8),
                                          salt: salt,
                                          iterations: iterations,
                                          keySize: PBKDF2KeyDeriver.defaultKeySize)
    }

    static func supportsEncryption(_ mode: EncryptionMode) -> Bool {
        switch mode {
        case .none:
            return true
        case .aes256Gcm:
            return CryptoSupport.aes256Gcm
        case .chacha20Poly1305:
            return CryptoSupport.chacha20Poly1305
        case .legacyAes128Cbc:
            return false
        @unknown default:
            return false
        }
    }

    static func supportsDecryption(_ mode: EncryptionMode) -> Bool {
        switch mode {
        case .none:
            return true
        case .aes256Gcm:
            return CryptoSupport.aes256Gcm
        case .chacha20Poly1305:
            return CryptoSupport.chacha20Poly1305
        case .legacyAes128Cbc:
            return CryptoSupport.legacyAes128Cbc
        @unknown default:
            return false
        }
    }
}
