//
//  ChaCha20Poly1305Crypter.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <array>
#include <cstdint>
#include <optional>
#include <span>

extern const std::size_t kChaCha20Poly1305KeySize SWIFT_NAME(ChaCha20Poly1305Crypter.keySize);
extern const std::size_t kChaCha20Poly1305NonceSize SWIFT_NAME(ChaCha20Poly1305Crypter.nonceSize);
extern const std::size_t kChaCha20Poly1305TagSize SWIFT_NAME(ChaCha20Poly1305Crypter.tagSize);

class SWIFT_UNCHECKED_SENDABLE ChaCha20Poly1305Crypter {
public:
    static constexpr std::size_t keySize = 32;
    static constexpr std::size_t nonceSize = 12;
    static constexpr std::size_t tagSize = 16;

    explicit ChaCha20Poly1305Crypter(std::array<uint8_t, keySize>) SWIFT_NAME(init(key:));
    explicit ChaCha20Poly1305Crypter(std::span<const uint8_t>) SWIFT_NAME(init(keySpan:));
    ChaCha20Poly1305Crypter(const ChaCha20Poly1305Crypter&) = default;
    ChaCha20Poly1305Crypter& operator=(const ChaCha20Poly1305Crypter&) = default;
    ~ChaCha20Poly1305Crypter() = default;

    using ByteSpan = std::span<const uint8_t>;
    using MutableByteSpan = std::span<uint8_t>;

    std::optional<size_t> encrypt(
        ByteSpan nonce,
        ByteSpan plaintext,
        MutableByteSpan destination
    ) const noexcept SWIFT_NAME(encrypt(nonce:plaintext:destination:));

    std::optional<size_t> decrypt(
        ByteSpan nonce,
        ByteSpan ciphertext,
        MutableByteSpan destination
    ) const noexcept SWIFT_NAME(decrypt(nonce:ciphertext:destination:));

private:
    std::array<uint8_t, keySize> key;
};
