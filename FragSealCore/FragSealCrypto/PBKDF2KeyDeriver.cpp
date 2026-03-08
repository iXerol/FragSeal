//
//  PBKDF2KeyDeriver.cpp
//  FragSealCrypto
//

#include "PBKDF2KeyDeriver.hpp"
#include "private/OpenSSLRuntime.hpp"
#include <limits>

const std::size_t kPBKDF2DefaultKeySize = PBKDF2KeyDeriver::defaultKeySize;

std::optional<size_t>
PBKDF2KeyDeriver::deriveSHA256(std::span<const uint8_t> password,
                               std::span<const uint8_t> salt,
                               std::uint32_t iterations,
                               std::span<uint8_t> destination) noexcept {
#if defined(FRAGSEAL_ENABLE_OPENSSL)
    if (password.size() > static_cast<std::size_t>(std::numeric_limits<int>::max()) ||
        salt.size() > static_cast<std::size_t>(std::numeric_limits<int>::max()) ||
        destination.size() > static_cast<std::size_t>(std::numeric_limits<int>::max()) ||
        iterations == 0) {
        return {};
    }

    const auto *symbols = fragseal::crypto::openssl_runtime::load_symbols();
    if (symbols == nullptr) {
        return {};
    }

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
    return result == 1 ? std::optional<size_t>(destination.size()) : std::optional<size_t>{};
#else
    (void)password;
    (void)salt;
    (void)iterations;
    (void)destination;
    return {};
#endif
}
