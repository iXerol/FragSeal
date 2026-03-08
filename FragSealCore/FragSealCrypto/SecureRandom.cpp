//
//  SecureRandom.cpp
//  FragSealCrypto
//

#include "SecureRandom.hpp"
#include "private/OpenSSLRuntime.hpp"
#include <limits>

bool SecureRandom::fill(std::span<uint8_t> destination) noexcept {
#if defined(FRAGSEAL_ENABLE_OPENSSL)
    if (destination.size() > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        return false;
    }
    const auto *symbols = fragseal::crypto::openssl_runtime::load_symbols();
    if (symbols == nullptr) {
        return false;
    }
    return symbols->rand_bytes(destination.data(), static_cast<int>(destination.size())) == 1;
#else
    (void)destination;
    return false;
#endif
}
