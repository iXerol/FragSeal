//
//  LegacyAes128CbcCrypter.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <array>
#include <cstdint>
#include <lifetimebound.h>
#include <memory>
#include "SpanTypes.hpp"

namespace fragseal::crypto::backend {
struct State;
}

extern const std::size_t kLegacyAes128CbcBlockSize SWIFT_NAME(LegacyAes128CbcCrypter.blockSize);

class SWIFT_UNCHECKED_SENDABLE LegacyAes128CbcCrypter {
public:
    static constexpr std::size_t blockSize = 16;

    explicit LegacyAes128CbcCrypter(std::array<uint8_t, blockSize>) SWIFT_NAME(init(key:));
    explicit LegacyAes128CbcCrypter(ByteSpan __noescape) SWIFT_NAME(init(keySpan:));
    LegacyAes128CbcCrypter(const LegacyAes128CbcCrypter&) = default;
    LegacyAes128CbcCrypter& operator=(const LegacyAes128CbcCrypter&) = default;
    ~LegacyAes128CbcCrypter() = default;

    OptionalSize decrypt(
        ByteSpan iv __noescape,
        ByteSpan ciphertext __noescape,
        MutableByteSpan destination __noescape
    ) const noexcept SWIFT_NAME(decrypt(iv:ciphertext:destination:));

private:
    std::array<uint8_t, blockSize> key;
    std::shared_ptr<const fragseal::crypto::backend::State> backendState;
};
