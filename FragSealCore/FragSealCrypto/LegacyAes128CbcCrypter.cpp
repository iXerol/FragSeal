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
    backendState = fragseal::crypto::backend::create_state(key);
}

LegacyAes128CbcCrypter::LegacyAes128CbcCrypter(std::span<const uint8_t> keySpan) {
    if (keySpan.size() != blockSize) {
        assert(false && "LegacyAes128CbcCrypter key must be 16 bytes");
        std::abort();
    }
    std::copy_n(keySpan.begin(), blockSize, key.begin());
    backendState = fragseal::crypto::backend::create_state(key);
}

std::optional<size_t>
LegacyAes128CbcCrypter::decrypt(LegacyAes128CbcCrypter::ByteSpan iv,
                                LegacyAes128CbcCrypter::ByteSpan ciphertext,
                                LegacyAes128CbcCrypter::MutableByteSpan destination) const noexcept {
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

    if (!backendState) {
        return {};
    }

    return fragseal::crypto::backend::decrypt(*backendState, iv, ciphertext, destination);
}
