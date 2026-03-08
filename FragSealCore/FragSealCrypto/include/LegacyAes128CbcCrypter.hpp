//
//  LegacyAes128CbcCrypter.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <array>
#include <optional>
#include <cstdint>
#include <memory>
#include <span>

namespace fragseal::crypto::backend {
struct State;
}

extern const std::size_t kLegacyAes128CbcBlockSize SWIFT_NAME(LegacyAes128CbcCrypter.blockSize);

class SWIFT_UNCHECKED_SENDABLE LegacyAes128CbcCrypter {
public:
    static constexpr std::size_t blockSize = 16;

    explicit LegacyAes128CbcCrypter(std::array<uint8_t, blockSize>) SWIFT_NAME(init(key:));
    explicit LegacyAes128CbcCrypter(std::span<const uint8_t>) SWIFT_NAME(init(keySpan:));
    LegacyAes128CbcCrypter(const LegacyAes128CbcCrypter&) = default;
    LegacyAes128CbcCrypter& operator=(const LegacyAes128CbcCrypter&) = default;
    ~LegacyAes128CbcCrypter() = default;

    using ByteSpan = std::span<const uint8_t>;
    using MutableByteSpan = std::span<uint8_t>;

    std::optional<size_t> decrypt(
        ByteSpan iv,
        ByteSpan ciphertext,
        MutableByteSpan destination
    ) const noexcept SWIFT_NAME(decrypt(iv:ciphertext:destination:));

private:
    std::array<uint8_t, blockSize> key;
    std::shared_ptr<const fragseal::crypto::backend::State> backendState;
};
