//
//  Aes256GcmCrypter.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <array>
#include <cstdint>
#include <optional>
#include <span>

extern const std::size_t kAes256GcmKeySize SWIFT_NAME(Aes256GcmCrypter.keySize);
extern const std::size_t kAes256GcmNonceSize SWIFT_NAME(Aes256GcmCrypter.nonceSize);
extern const std::size_t kAes256GcmTagSize SWIFT_NAME(Aes256GcmCrypter.tagSize);

class SWIFT_UNCHECKED_SENDABLE Aes256GcmCrypter {
public:
    static constexpr std::size_t keySize = 32;
    static constexpr std::size_t nonceSize = 12;
    static constexpr std::size_t tagSize = 16;

    explicit Aes256GcmCrypter(std::array<uint8_t, keySize>) SWIFT_NAME(init(key:));
    explicit Aes256GcmCrypter(std::span<const uint8_t>) SWIFT_NAME(init(keySpan:));
    Aes256GcmCrypter(const Aes256GcmCrypter&) = default;
    Aes256GcmCrypter& operator=(const Aes256GcmCrypter&) = default;
    ~Aes256GcmCrypter() = default;

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
