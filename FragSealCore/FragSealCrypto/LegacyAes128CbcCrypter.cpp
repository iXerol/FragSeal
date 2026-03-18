//
//  LegacyAes128CbcCrypter.cpp
//  FragSealCrypto
//
//  C++ implementation used by Swift via direct pointer bridging.
//

#include "LegacyAes128CbcCrypter.hpp"
#include "private/LegacyAes128CbcCrypterBackend.hpp"
#include <algorithm>
#include <cassert>
#include <cstdlib>

const std::size_t kLegacyAes128CbcBlockSize = LegacyAes128CbcCrypter::blockSize;

LegacyAes128CbcCrypter::LegacyAes128CbcCrypter(std::array<uint8_t, blockSize> keyBytes) {
    this->key = keyBytes;
#if defined(FRAGSEAL_USE_OPENSSL)
    opensslState = fragseal::crypto::backend::openssl_backend::create_state(key);
#endif
#if defined(FRAGSEAL_USE_COMMONCRYPTO)
    if (!opensslState) {
        commoncryptoState = fragseal::crypto::backend::commoncrypto_backend::create_state(key);
    }
#endif
}

LegacyAes128CbcCrypter::LegacyAes128CbcCrypter(ByteSpan keySpan __noescape) {
    if (keySpan.size() != blockSize) {
        assert(false && "LegacyAes128CbcCrypter key must be 16 bytes");
        std::abort();
    }
    std::copy_n(keySpan.begin(), blockSize, key.begin());
#if defined(FRAGSEAL_USE_OPENSSL)
    opensslState = fragseal::crypto::backend::openssl_backend::create_state(key);
#endif
#if defined(FRAGSEAL_USE_COMMONCRYPTO)
    if (!opensslState) {
        commoncryptoState = fragseal::crypto::backend::commoncrypto_backend::create_state(key);
    }
#endif
}

OptionalSize
LegacyAes128CbcCrypter::decrypt(ByteSpan iv __noescape,
                                ByteSpan ciphertext __noescape,
                                MutableByteSpan destination __noescape) const noexcept {
    if (iv.size() != blockSize) {
        return {};
    }

    const auto bufferCount = ciphertext.size();

    if (bufferCount == 0 || destination.size() < bufferCount) {
        return {};
    }

    // Allow in-place decryption by sharing the same backing storage.
    if (destination.data() != ciphertext.data()) {
        std::copy_n(ciphertext.begin(), bufferCount, destination.begin());
    }

#if defined(FRAGSEAL_USE_OPENSSL)
    if (opensslState) {
        return fragseal::crypto::backend::openssl_backend::decrypt(*opensslState, iv, ciphertext, destination);
    }
#endif
#if defined(FRAGSEAL_USE_COMMONCRYPTO)
    if (commoncryptoState) {
        return fragseal::crypto::backend::commoncrypto_backend::decrypt(
            *commoncryptoState, iv, ciphertext, destination
        );
    }
#endif
    return {};
}
