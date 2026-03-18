//
//  LegacyAes128CbcCrypterOpenSSL.cpp
//  FragSealCrypto
//
//  OpenSSL symbol loading and context ownership.
//

#include "private/LegacyAes128CbcCrypterBackend.hpp"
#include "private/OpenSSLRuntime.hpp"
#include <limits>
#include <memory>
#include <mutex>

#if defined(FRAGSEAL_USE_OPENSSL)

namespace fragseal::crypto::backend::openssl_backend {

struct State {
    const fragseal::crypto::openssl_runtime::Symbols *symbols = nullptr;
    EVP_CIPHER_CTX *templateCtx = nullptr;
    mutable std::mutex templateMutex;

    ~State() {
        if (templateCtx != nullptr && symbols != nullptr && symbols->evp_cipher_ctx_free != nullptr) {
            symbols->evp_cipher_ctx_free(templateCtx);
        }
    }
};

std::shared_ptr<const State> create_state(
    const std::array<uint8_t, LegacyAes128CbcCrypter::blockSize> &key) noexcept {
    const auto *symbols = fragseal::crypto::openssl_runtime::load_symbols();
    if (symbols == nullptr) {
        return {};
    }

    auto state = std::make_shared<State>();
    state->symbols = symbols;
    state->templateCtx = symbols->evp_cipher_ctx_new();
    if (state->templateCtx == nullptr) {
        return {};
    }

    if (symbols->evp_decrypt_init_ex(state->templateCtx, symbols->evp_aes_128_cbc(),
                                     nullptr, key.data(), nullptr) != 1) {
        return {};
    }

    if (symbols->evp_cipher_ctx_set_padding(state->templateCtx, 1) != 1) {
        return {};
    }

    return state;
}

OptionalSize decrypt(
    const State &state,
    ByteSpan iv,
    ByteSpan ciphertext,
    MutableByteSpan destination) noexcept {
    const auto bufferCount = ciphertext.size();
    if (bufferCount > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        return {};
    }

    const auto *symbols = state.symbols;
    if (symbols == nullptr || state.templateCtx == nullptr) {
        return {};
    }

    fragseal::crypto::openssl_runtime::CipherCtx ctx(*symbols);
    if (ctx.get() == nullptr) {
        return {};
    }

    {
        std::lock_guard<std::mutex> lock(state.templateMutex);
        if (symbols->evp_cipher_ctx_copy(ctx.get(), state.templateCtx) != 1) {
            return {};
        }
    }

    // Reuse cached key schedule, set per-call IV.
    if (symbols->evp_decrypt_init_ex(ctx.get(), nullptr, nullptr, nullptr, iv.data()) != 1) {
        return {};
    }

    int outLen1 = 0;
    if (symbols->evp_decrypt_update(ctx.get(), destination.data(), &outLen1,
                                    destination.data(),
                                    static_cast<int>(bufferCount)) != 1) {
        return {};
    }

    int outLen2 = 0;
    if (symbols->evp_decrypt_final_ex(
            ctx.get(), destination.data() + static_cast<std::size_t>(outLen1),
            &outLen2) != 1) {
        return {};
    }

    return static_cast<size_t>(outLen1 + outLen2);
}

} // namespace fragseal::crypto::backend::openssl_backend

#endif
