//
//  ChaCha20Poly1305Crypter.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <array>
#include <cstdint>
#include <lifetimebound.h>
#include "SpanTypes.hpp"

extern const std::size_t kChaCha20Poly1305KeySize SWIFT_NAME(ChaCha20Poly1305Crypter.keySize);
extern const std::size_t kChaCha20Poly1305NonceSize SWIFT_NAME(ChaCha20Poly1305Crypter.nonceSize);
extern const std::size_t kChaCha20Poly1305TagSize SWIFT_NAME(ChaCha20Poly1305Crypter.tagSize);

class SWIFT_UNCHECKED_SENDABLE ChaCha20Poly1305Crypter {
public:
    static constexpr std::size_t keySize = 32;
    static constexpr std::size_t nonceSize = 12;
    static constexpr std::size_t tagSize = 16;

    explicit ChaCha20Poly1305Crypter(std::array<uint8_t, keySize>) SWIFT_NAME(init(key:));
    explicit ChaCha20Poly1305Crypter(ByteSpan key __noescape) SWIFT_NAME(init(keySpan:));
    ChaCha20Poly1305Crypter(const ChaCha20Poly1305Crypter&) = default;
    ChaCha20Poly1305Crypter& operator=(const ChaCha20Poly1305Crypter&) = default;
    ~ChaCha20Poly1305Crypter() = default;

    OptionalSize encrypt(
        ByteSpan nonce __noescape,
        ByteSpan plaintext __noescape,
        MutableByteSpan destination __noescape
    ) const noexcept SWIFT_NAME(encrypt(nonce:plaintext:destination:));

    OptionalSize decrypt(
        ByteSpan nonce __noescape,
        ByteSpan ciphertext __noescape,
        MutableByteSpan destination __noescape
    ) const noexcept SWIFT_NAME(decrypt(nonce:ciphertext:destination:));

private:
    std::array<uint8_t, keySize> key;
};
