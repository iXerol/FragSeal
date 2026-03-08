//
//  PBKDF2KeyDeriver.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <cstdint>
#include <optional>
#include <span>

extern const std::size_t kPBKDF2DefaultKeySize SWIFT_NAME(PBKDF2KeyDeriver.defaultKeySize);

class SWIFT_UNCHECKED_SENDABLE PBKDF2KeyDeriver {
public:
    static constexpr std::size_t defaultKeySize = 32;

    static std::optional<size_t> deriveSHA256(
        std::span<const uint8_t> password,
        std::span<const uint8_t> salt,
        std::uint32_t iterations,
        std::span<uint8_t> destination
    ) noexcept SWIFT_NAME(deriveSHA256(password:salt:iterations:destination:));
};
