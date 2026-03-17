//
//  SecureRandom.hpp
//  FragSealCrypto
//

#pragma once

#include <lifetimebound.h>
#include <swift/bridging>
#include "SpanTypes.hpp"

class SWIFT_UNCHECKED_SENDABLE SecureRandom {
public:
    static bool fill(
        MutableByteSpan destination __noescape
    ) noexcept SWIFT_NAME(fill(destination:));
};
