//
//  SecureRandom.hpp
//  FragSealCrypto
//

#pragma once

#include <cstdint>
#include <swift/bridging>
#include <span>

class SWIFT_UNCHECKED_SENDABLE SecureRandom {
public:
    static bool fill(
        std::span<uint8_t> destination
    ) noexcept SWIFT_NAME(fill(destination:));
};
