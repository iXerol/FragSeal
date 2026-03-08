//
//  SHA256Hasher.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <cstdint>
#include <optional>
#include <span>

extern const std::size_t kSHA256DigestSize SWIFT_NAME(SHA256Hasher.digestSize);

class SWIFT_UNCHECKED_SENDABLE SHA256Hasher {
public:
    static constexpr std::size_t digestSize = 32;

    static std::optional<size_t> hash(
        std::span<const uint8_t> data,
        std::span<uint8_t> destination
    ) noexcept SWIFT_NAME(hash(data:destination:));
};
