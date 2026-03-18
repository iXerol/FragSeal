//
//  PBKDF2KeyDeriver.cpp
//  FragSealCrypto
//

#include "PBKDF2KeyDeriver.hpp"
#include "private/OpenSSLRuntime.hpp"
#include <limits>

const std::size_t kPBKDF2DefaultKeySize = PBKDF2KeyDeriver::defaultKeySize;

OptionalSize
PBKDF2KeyDeriver::deriveSHA256(ByteSpan password __noescape,
                               ByteSpan salt __noescape,
                               std::uint32_t iterations,
                               MutableByteSpan destination __noescape) noexcept {
#if defined(FRAGSEAL_ENABLE_OPENSSL)
    if (password.size() > static_cast<std::size_t>(std::numeric_limits<int>::max()) ||
        salt.size() > static_cast<std::size_t>(std::numeric_limits<int>::max()) ||
        destination.size() > static_cast<std::size_t>(std::numeric_limits<int>::max()) ||
        iterations == 0) {
        return {};
    }

    const auto *symbols = fragseal::crypto::openssl_runtime::load_symbols();
    if (symbols != nullptr) {
        const auto result = symbols->pkcs5_pbkdf2_hmac(
            reinterpret_cast<const char *>(password.data()),
            static_cast<int>(password.size()),
            salt.data(),
            static_cast<int>(salt.size()),
            static_cast<int>(iterations),
            symbols->evp_sha256(),
            static_cast<int>(destination.size()),
            destination.data()
        );
        if (result == 1) {
            return destination.size();
        }
    }

#if defined(FRAGSEAL_USE_COMMONCRYPTO)
    const auto status = CCKeyDerivationPBKDF(
        kCCPBKDF2,
        reinterpret_cast<const char *>(password.data()),
        static_cast<int>(password.size()),
        salt.data(),
        static_cast<int>(salt.size()),
        kCCPRFHmacAlgSHA256,
        static_cast<unsigned>(iterations),
        destination.data(),
        destination.size()
    );
    return status == kCCSuccess ? std::optional<size_t>(destination.size()) : std::optional<size_t>{};
#else
    return {};
#endif
#elif defined(FRAGSEAL_USE_COMMONCRYPTO)
    if (iterations == 0
        || password.size() > static_cast<std::size_t>(std::numeric_limits<int>::max())
        || salt.size() > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        return {};
    }

    const auto status = CCKeyDerivationPBKDF(
        kCCPBKDF2,
        reinterpret_cast<const char *>(password.data()),
        static_cast<int>(password.size()),
        salt.data(),
        static_cast<int>(salt.size()),
        kCCPRFHmacAlgSHA256,
        static_cast<unsigned>(iterations),
        destination.data(),
        destination.size()
    );
    return status == kCCSuccess ? std::optional<size_t>(destination.size()) : std::optional<size_t>{};
#else
    (void)password;
    (void)salt;
    (void)iterations;
    (void)destination;
    return {};
#endif
}
