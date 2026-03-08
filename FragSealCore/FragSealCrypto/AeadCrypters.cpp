//
//  AeadCrypters.cpp
//  FragSealCrypto
//

#include "Aes256GcmCrypter.hpp"
#include "ChaCha20Poly1305Crypter.hpp"
#include "private/OpenSSLRuntime.hpp"
#include <algorithm>
#include <array>
#include <cassert>
#include <cstdlib>
#include <limits>

#if defined(FRAGSEAL_ENABLE_OPENSSL)

const std::size_t kAes256GcmKeySize = Aes256GcmCrypter::keySize;
const std::size_t kAes256GcmNonceSize = Aes256GcmCrypter::nonceSize;
const std::size_t kAes256GcmTagSize = Aes256GcmCrypter::tagSize;
const std::size_t kChaCha20Poly1305KeySize = ChaCha20Poly1305Crypter::keySize;
const std::size_t kChaCha20Poly1305NonceSize = ChaCha20Poly1305Crypter::nonceSize;
const std::size_t kChaCha20Poly1305TagSize = ChaCha20Poly1305Crypter::tagSize;

namespace {

template <typename Crypter>
void copyKey(std::span<const uint8_t> keySpan,
             std::array<uint8_t, Crypter::keySize> &destination,
             const char *message) {
    if (keySpan.size() != Crypter::keySize) {
        assert(false && message);
        std::abort();
    }
    std::copy_n(keySpan.begin(), Crypter::keySize, destination.begin());
}

template <typename Crypter, typename CipherGetter>
std::optional<size_t> encryptAEAD(
    const std::array<uint8_t, Crypter::keySize> &key,
    typename Crypter::ByteSpan nonce,
    typename Crypter::ByteSpan plaintext,
    typename Crypter::MutableByteSpan destination,
    CipherGetter cipherGetter
) noexcept {
    if (nonce.size() != Crypter::nonceSize || destination.size() < plaintext.size() + Crypter::tagSize) {
        return {};
    }
    if (plaintext.size() > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        return {};
    }

    const auto *symbols = fragseal::crypto::openssl_runtime::load_symbols();
    if (symbols == nullptr) {
        return {};
    }

    fragseal::crypto::openssl_runtime::CipherCtx ctx(*symbols);
    if (ctx.get() == nullptr) {
        return {};
    }

    if (symbols->evp_encrypt_init_ex(ctx.get(), cipherGetter(*symbols), nullptr, nullptr, nullptr) != 1) {
        return {};
    }
    if (symbols->evp_cipher_ctx_ctrl(ctx.get(), EVP_CTRL_AEAD_SET_IVLEN,
                                     static_cast<int>(nonce.size()), nullptr) != 1) {
        return {};
    }
    if (symbols->evp_encrypt_init_ex(ctx.get(), nullptr, nullptr, key.data(), nonce.data()) != 1) {
        return {};
    }

    int outLen1 = 0;
    if (symbols->evp_encrypt_update(ctx.get(), destination.data(), &outLen1,
                                    plaintext.data(), static_cast<int>(plaintext.size())) != 1) {
        return {};
    }

    int outLen2 = 0;
    if (symbols->evp_encrypt_final_ex(ctx.get(), destination.data() + outLen1, &outLen2) != 1) {
        return {};
    }

    std::array<uint8_t, Crypter::tagSize> tag{};
    if (symbols->evp_cipher_ctx_ctrl(ctx.get(), EVP_CTRL_AEAD_GET_TAG,
                                     static_cast<int>(tag.size()), tag.data()) != 1) {
        return {};
    }

    const auto total = static_cast<size_t>(outLen1 + outLen2);
    std::copy(tag.begin(), tag.end(), destination.begin() + static_cast<std::ptrdiff_t>(total));
    return total + tag.size();
}

template <typename Crypter, typename CipherGetter>
std::optional<size_t> decryptAEAD(
    const std::array<uint8_t, Crypter::keySize> &key,
    typename Crypter::ByteSpan nonce,
    typename Crypter::ByteSpan ciphertext,
    typename Crypter::MutableByteSpan destination,
    CipherGetter cipherGetter
) noexcept {
    if (nonce.size() != Crypter::nonceSize || ciphertext.size() < Crypter::tagSize) {
        return {};
    }

    const auto bodySize = ciphertext.size() - Crypter::tagSize;
    if (destination.size() < bodySize || bodySize > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        return {};
    }

    const auto *symbols = fragseal::crypto::openssl_runtime::load_symbols();
    if (symbols == nullptr) {
        return {};
    }

    fragseal::crypto::openssl_runtime::CipherCtx ctx(*symbols);
    if (ctx.get() == nullptr) {
        return {};
    }

    if (symbols->evp_decrypt_init_ex(ctx.get(), cipherGetter(*symbols), nullptr, nullptr, nullptr) != 1) {
        return {};
    }
    if (symbols->evp_cipher_ctx_ctrl(ctx.get(), EVP_CTRL_AEAD_SET_IVLEN,
                                     static_cast<int>(nonce.size()), nullptr) != 1) {
        return {};
    }
    if (symbols->evp_decrypt_init_ex(ctx.get(), nullptr, nullptr, key.data(), nonce.data()) != 1) {
        return {};
    }

    int outLen1 = 0;
    if (symbols->evp_decrypt_update(ctx.get(), destination.data(), &outLen1,
                                    ciphertext.data(), static_cast<int>(bodySize)) != 1) {
        return {};
    }

    std::array<uint8_t, Crypter::tagSize> tag{};
    std::copy(ciphertext.end() - static_cast<std::ptrdiff_t>(Crypter::tagSize),
              ciphertext.end(), tag.begin());
    if (symbols->evp_cipher_ctx_ctrl(ctx.get(), EVP_CTRL_AEAD_SET_TAG,
                                     static_cast<int>(tag.size()), tag.data()) != 1) {
        return {};
    }

    int outLen2 = 0;
    if (symbols->evp_decrypt_final_ex(ctx.get(),
                                      destination.data() + static_cast<std::size_t>(outLen1),
                                      &outLen2) != 1) {
        return {};
    }

    return static_cast<size_t>(outLen1 + outLen2);
}

} // namespace

Aes256GcmCrypter::Aes256GcmCrypter(std::array<uint8_t, keySize> keyBytes) : key(keyBytes) {}

Aes256GcmCrypter::Aes256GcmCrypter(std::span<const uint8_t> keySpan) {
    copyKey<Aes256GcmCrypter>(keySpan, key, "Aes256GcmCrypter key must be 32 bytes");
}

std::optional<size_t>
Aes256GcmCrypter::encrypt(ByteSpan nonce,
                          ByteSpan plaintext,
                          MutableByteSpan destination) const noexcept {
    return encryptAEAD<Aes256GcmCrypter>(key, nonce, plaintext, destination,
                                         [](const fragseal::crypto::openssl_runtime::Symbols &symbols) {
                                             return symbols.evp_aes_256_gcm();
                                         });
}

std::optional<size_t>
Aes256GcmCrypter::decrypt(ByteSpan nonce,
                          ByteSpan ciphertext,
                          MutableByteSpan destination) const noexcept {
    return decryptAEAD<Aes256GcmCrypter>(key, nonce, ciphertext, destination,
                                         [](const fragseal::crypto::openssl_runtime::Symbols &symbols) {
                                             return symbols.evp_aes_256_gcm();
                                         });
}

ChaCha20Poly1305Crypter::ChaCha20Poly1305Crypter(std::array<uint8_t, keySize> keyBytes) : key(keyBytes) {}

ChaCha20Poly1305Crypter::ChaCha20Poly1305Crypter(std::span<const uint8_t> keySpan) {
    copyKey<ChaCha20Poly1305Crypter>(keySpan, key, "ChaCha20Poly1305Crypter key must be 32 bytes");
}

std::optional<size_t>
ChaCha20Poly1305Crypter::encrypt(ByteSpan nonce,
                                 ByteSpan plaintext,
                                 MutableByteSpan destination) const noexcept {
    return encryptAEAD<ChaCha20Poly1305Crypter>(key, nonce, plaintext, destination,
                                                [](const fragseal::crypto::openssl_runtime::Symbols &symbols) {
                                                    return symbols.evp_chacha20_poly1305();
                                                });
}

std::optional<size_t>
ChaCha20Poly1305Crypter::decrypt(ByteSpan nonce,
                                 ByteSpan ciphertext,
                                 MutableByteSpan destination) const noexcept {
    return decryptAEAD<ChaCha20Poly1305Crypter>(key, nonce, ciphertext, destination,
                                                [](const fragseal::crypto::openssl_runtime::Symbols &symbols) {
                                                    return symbols.evp_chacha20_poly1305();
                                                });
}

#else

const std::size_t kAes256GcmKeySize = Aes256GcmCrypter::keySize;
const std::size_t kAes256GcmNonceSize = Aes256GcmCrypter::nonceSize;
const std::size_t kAes256GcmTagSize = Aes256GcmCrypter::tagSize;
const std::size_t kChaCha20Poly1305KeySize = ChaCha20Poly1305Crypter::keySize;
const std::size_t kChaCha20Poly1305NonceSize = ChaCha20Poly1305Crypter::nonceSize;
const std::size_t kChaCha20Poly1305TagSize = ChaCha20Poly1305Crypter::tagSize;

Aes256GcmCrypter::Aes256GcmCrypter(std::array<uint8_t, keySize>) {}
Aes256GcmCrypter::Aes256GcmCrypter(std::span<const uint8_t>) {}
std::optional<size_t> Aes256GcmCrypter::encrypt(ByteSpan, ByteSpan, MutableByteSpan) const noexcept { return {}; }
std::optional<size_t> Aes256GcmCrypter::decrypt(ByteSpan, ByteSpan, MutableByteSpan) const noexcept { return {}; }

ChaCha20Poly1305Crypter::ChaCha20Poly1305Crypter(std::array<uint8_t, keySize>) {}
ChaCha20Poly1305Crypter::ChaCha20Poly1305Crypter(std::span<const uint8_t>) {}
std::optional<size_t> ChaCha20Poly1305Crypter::encrypt(ByteSpan, ByteSpan, MutableByteSpan) const noexcept { return {}; }
std::optional<size_t> ChaCha20Poly1305Crypter::decrypt(ByteSpan, ByteSpan, MutableByteSpan) const noexcept { return {}; }

#endif
