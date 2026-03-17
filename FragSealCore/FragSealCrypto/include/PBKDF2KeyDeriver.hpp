//
//  PBKDF2KeyDeriver.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <cstdint>
#include <lifetimebound.h>
#include "SpanTypes.hpp"

extern const std::size_t kPBKDF2DefaultKeySize SWIFT_NAME(PBKDF2KeyDeriver.defaultKeySize);

class SWIFT_UNCHECKED_SENDABLE PBKDF2KeyDeriver {
public:
    static constexpr std::size_t defaultKeySize = 32;

    static OptionalSize deriveSHA256(
        ByteSpan password __noescape,
        ByteSpan salt __noescape,
        std::uint32_t iterations,
        MutableByteSpan destination __noescape
    ) noexcept SWIFT_NAME(deriveSHA256(password:salt:iterations:destination:));
};
