//
//  SHA256Hasher.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>
#include <lifetimebound.h>
#include "SpanTypes.hpp"

extern const std::size_t kSHA256DigestSize SWIFT_NAME(SHA256Hasher.digestSize);

class SWIFT_UNCHECKED_SENDABLE SHA256Hasher {
public:
    static constexpr std::size_t digestSize = 32;

    static OptionalSize hash(
        ByteSpan data __noescape,
        MutableByteSpan destination __noescape
    ) noexcept SWIFT_NAME(hash(data:destination:));
};
