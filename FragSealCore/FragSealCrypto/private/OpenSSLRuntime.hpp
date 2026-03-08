#pragma once

#include "CryptoBackendConfig.hpp"

#if defined(FRAGSEAL_ENABLE_OPENSSL)

#include <dlfcn.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/sha.h>
#include <memory>

namespace fragseal::crypto::openssl_runtime {

struct Symbols final {
    decltype(&EVP_CIPHER_CTX_new) evp_cipher_ctx_new = nullptr;
    decltype(&EVP_CIPHER_CTX_free) evp_cipher_ctx_free = nullptr;
    decltype(&EVP_CIPHER_CTX_copy) evp_cipher_ctx_copy = nullptr;
    decltype(&EVP_CIPHER_CTX_set_padding) evp_cipher_ctx_set_padding = nullptr;
    decltype(&EVP_CIPHER_CTX_ctrl) evp_cipher_ctx_ctrl = nullptr;
    decltype(&EVP_EncryptInit_ex) evp_encrypt_init_ex = nullptr;
    decltype(&EVP_EncryptUpdate) evp_encrypt_update = nullptr;
    decltype(&EVP_EncryptFinal_ex) evp_encrypt_final_ex = nullptr;
    decltype(&EVP_DecryptInit_ex) evp_decrypt_init_ex = nullptr;
    decltype(&EVP_DecryptUpdate) evp_decrypt_update = nullptr;
    decltype(&EVP_DecryptFinal_ex) evp_decrypt_final_ex = nullptr;
    decltype(&EVP_aes_128_cbc) evp_aes_128_cbc = nullptr;
    decltype(&EVP_aes_256_gcm) evp_aes_256_gcm = nullptr;
    decltype(&EVP_chacha20_poly1305) evp_chacha20_poly1305 = nullptr;
    decltype(&EVP_sha256) evp_sha256 = nullptr;
    decltype(&PKCS5_PBKDF2_HMAC) pkcs5_pbkdf2_hmac = nullptr;
    decltype(&RAND_bytes) rand_bytes = nullptr;
    decltype(&SHA256) sha256 = nullptr;
};

const Symbols *load_symbols() noexcept;

class CipherCtx final {
public:
    explicit CipherCtx(const Symbols &symbols) noexcept;
    ~CipherCtx();

    CipherCtx(const CipherCtx &) = delete;
    CipherCtx &operator=(const CipherCtx &) = delete;

    EVP_CIPHER_CTX *get() const noexcept { return ctx_; }

private:
    EVP_CIPHER_CTX *ctx_ = nullptr;
    decltype(&EVP_CIPHER_CTX_free) free_fn_ = nullptr;
};

} // namespace fragseal::crypto::openssl_runtime

#endif
