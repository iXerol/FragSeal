//
//  SecureRandom.cpp
//  FragSealCrypto
//

#include "SecureRandom.hpp"
#include "private/OpenSSLRuntime.hpp"
#include <limits>

#if defined(FRAGSEAL_USE_COMMONCRYPTO)
#include <CommonCrypto/CommonRandom.h>
#endif

bool SecureRandom::fill(MutableByteSpan destination __noescape) noexcept {
#if defined(FRAGSEAL_ENABLE_OPENSSL)
    if (destination.size() > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        return false;
    }
    const auto *symbols = fragseal::crypto::openssl_runtime::load_symbols();
    if (symbols != nullptr && symbols->rand_bytes(destination.data(), static_cast<int>(destination.size())) == 1) {
        return true;
    }

#if defined(FRAGSEAL_USE_COMMONCRYPTO)
    return CCRandomGenerateBytes(destination.data(), destination.size()) == kCCSuccess;
#else
    return false;
#endif
#elif defined(FRAGSEAL_USE_COMMONCRYPTO)
    return CCRandomGenerateBytes(destination.data(), destination.size()) == kCCSuccess;
#else
    (void)destination;
    return false;
#endif
}
