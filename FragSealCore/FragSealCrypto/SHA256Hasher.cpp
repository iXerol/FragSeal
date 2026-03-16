//
//  SHA256Hasher.cpp
//  FragSealCrypto
//

#include "SHA256Hasher.hpp"
#include "private/OpenSSLRuntime.hpp"
#include <limits>

const std::size_t kSHA256DigestSize = SHA256Hasher::digestSize;

OptionalSize
SHA256Hasher::hash(ByteSpan data __noescape,
                   MutableByteSpan destination __noescape) noexcept {
#if defined(FRAGSEAL_ENABLE_OPENSSL)
    if (destination.size() < digestSize ||
        data.size() > static_cast<std::size_t>(std::numeric_limits<unsigned long>::max())) {
        return {};
    }

    const auto *symbols = fragseal::crypto::openssl_runtime::load_symbols();
    if (symbols == nullptr) {
        return {};
    }

    return symbols->sha256(data.data(), static_cast<unsigned long>(data.size()), destination.data()) != nullptr
        ? std::optional<size_t>(digestSize)
        : std::optional<size_t>{};
#else
    (void)data;
    (void)destination;
    return {};
#endif
}
