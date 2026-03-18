//
//  CryptoCapabilities.hpp
//  FragSealCrypto
//

#pragma once

#include <swift/bridging>

class SWIFT_UNCHECKED_SENDABLE CryptoCapabilities {
public:
    static bool supportsAes256Gcm() noexcept;
    static bool supportsChaCha20Poly1305() noexcept;
    static bool supportsLegacyAes128Cbc() noexcept;
};
