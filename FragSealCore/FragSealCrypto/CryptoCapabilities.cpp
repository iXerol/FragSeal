//
//  CryptoCapabilities.cpp
//  FragSealCrypto
//

#include "CryptoCapabilities.hpp"
#include "private/CryptoBackendConfig.hpp"

#if defined(FRAGSEAL_ENABLE_OPENSSL)
#include "private/OpenSSLRuntime.hpp"
#endif

namespace {

bool hasOpenSSLRuntime() noexcept {
#if defined(FRAGSEAL_ENABLE_OPENSSL)
    return fragseal::crypto::openssl_runtime::load_symbols() != nullptr;
#else
    return false;
#endif
}

} // namespace

bool CryptoCapabilities::supportsAes256Gcm() noexcept {
    return hasOpenSSLRuntime();
}

bool CryptoCapabilities::supportsChaCha20Poly1305() noexcept {
    return hasOpenSSLRuntime();
}

bool CryptoCapabilities::supportsLegacyAes128Cbc() noexcept {
#if defined(FRAGSEAL_USE_COMMONCRYPTO)
    return true;
#elif defined(FRAGSEAL_USE_OPENSSL)
    return hasOpenSSLRuntime();
#else
    return false;
#endif
}
