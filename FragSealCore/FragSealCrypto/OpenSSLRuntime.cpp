//
//  OpenSSLRuntime.cpp
//  FragSealCrypto
//

#include "private/OpenSSLRuntime.hpp"

#if defined(FRAGSEAL_ENABLE_OPENSSL)

#include <cstdlib>
#include <mutex>

namespace fragseal::crypto::openssl_runtime {

namespace {

bool opensslForcedUnavailable() noexcept {
    const auto *value = std::getenv("FRAGSEAL_OPENSSL_FORCE_UNAVAILABLE");
    if (value == nullptr || value[0] == '\0') {
        return false;
    }
    return !(value[0] == '0' && value[1] == '\0');
}

struct Loader final {
    Symbols symbols;
    void *handle = nullptr;

    template <typename FnType>
    bool loadSymbol(const char *symbolName, FnType &symbol) {
        symbol = reinterpret_cast<FnType>(dlsym(handle, symbolName));
        return symbol != nullptr;
    }

    bool initialize() {
#if defined(__APPLE__)
        static constexpr const char *kCandidates[] = {
            "libcrypto.3.dylib",
            "@rpath/libcrypto.3.dylib",
            "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib",
            "/usr/local/opt/openssl@3/lib/libcrypto.3.dylib",
            "/opt/local/lib/libcrypto.3.dylib",
        };
#else
        static constexpr const char *kCandidates[] = {
            "libcrypto.so.3",
            "libcrypto.so",
        };
#endif

        auto tryOpen = [&](const char *candidate) {
            if (candidate == nullptr || candidate[0] == '\0') {
                return false;
            }
            handle = dlopen(candidate, RTLD_LAZY | RTLD_LOCAL);
            return handle != nullptr;
        };

        const auto *overrideLib = std::getenv("FRAGSEAL_OPENSSL_CRYPTO_LIB");
        if (!tryOpen(overrideLib)) {
            for (const auto *candidate : kCandidates) {
                if (tryOpen(candidate)) {
                    break;
                }
            }
        }

        if (handle == nullptr) {
            return false;
        }

        return loadSymbol("EVP_CIPHER_CTX_new", symbols.evp_cipher_ctx_new) &&
               loadSymbol("EVP_CIPHER_CTX_free", symbols.evp_cipher_ctx_free) &&
               loadSymbol("EVP_CIPHER_CTX_copy", symbols.evp_cipher_ctx_copy) &&
               loadSymbol("EVP_CIPHER_CTX_set_padding", symbols.evp_cipher_ctx_set_padding) &&
               loadSymbol("EVP_CIPHER_CTX_ctrl", symbols.evp_cipher_ctx_ctrl) &&
               loadSymbol("EVP_EncryptInit_ex", symbols.evp_encrypt_init_ex) &&
               loadSymbol("EVP_EncryptUpdate", symbols.evp_encrypt_update) &&
               loadSymbol("EVP_EncryptFinal_ex", symbols.evp_encrypt_final_ex) &&
               loadSymbol("EVP_DecryptInit_ex", symbols.evp_decrypt_init_ex) &&
               loadSymbol("EVP_DecryptUpdate", symbols.evp_decrypt_update) &&
               loadSymbol("EVP_DecryptFinal_ex", symbols.evp_decrypt_final_ex) &&
               loadSymbol("EVP_aes_128_cbc", symbols.evp_aes_128_cbc) &&
               loadSymbol("EVP_aes_256_gcm", symbols.evp_aes_256_gcm) &&
               loadSymbol("EVP_chacha20_poly1305", symbols.evp_chacha20_poly1305) &&
               loadSymbol("EVP_sha256", symbols.evp_sha256) &&
               loadSymbol("PKCS5_PBKDF2_HMAC", symbols.pkcs5_pbkdf2_hmac) &&
               loadSymbol("RAND_bytes", symbols.rand_bytes) &&
               loadSymbol("SHA256", symbols.sha256);
    }
};

} // namespace

const Symbols *load_symbols() noexcept {
    if (opensslForcedUnavailable()) {
        return nullptr;
    }

    static Loader loader;
    static std::once_flag onceFlag;
    static bool loaded = false;
    std::call_once(onceFlag, [&]() { loaded = loader.initialize(); });
    return loaded ? &loader.symbols : nullptr;
}

CipherCtx::CipherCtx(const Symbols &symbols) noexcept
    : ctx_(symbols.evp_cipher_ctx_new()),
      free_fn_(symbols.evp_cipher_ctx_free) {}

CipherCtx::~CipherCtx() {
    if (ctx_ != nullptr && free_fn_ != nullptr) {
        free_fn_(ctx_);
    }
}

} // namespace fragseal::crypto::openssl_runtime

#endif
