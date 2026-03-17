//
//  LegacyAes128CbcCrypterCommonCrypto.cpp
//  FragSealCrypto
//

#include "private/LegacyAes128CbcCrypterBackend.hpp"

#if defined(FRAGSEAL_USE_COMMONCRYPTO)

namespace fragseal::crypto::backend {
struct State {
    std::array<uint8_t, LegacyAes128CbcCrypter::blockSize> key;
};

std::shared_ptr<const State> create_state(
    const std::array<uint8_t, LegacyAes128CbcCrypter::blockSize> &key) noexcept {
    return std::make_shared<const State>(State{ key });
}

OptionalSize decrypt(
    const State &                    state,
    ByteSpan                         iv,
    ByteSpan                         ciphertext,
    MutableByteSpan                  destination) noexcept {
    static_assert(kCCBlockSizeAES128 == LegacyAes128CbcCrypter::blockSize);

    size_t bytesDecrypted = 0;
    const auto status = CCCrypt(
        CCOperation(kCCDecrypt),
        CCAlgorithm(kCCAlgorithmAES128),
        CCOptions(kCCOptionPKCS7Padding),
        state.key.data(), state.key.size(),
        iv.data(), destination.data(),
        ciphertext.size(), destination.data(),
        ciphertext.size(), &bytesDecrypted);

    if (status != kCCSuccess) {
        return {};
    }

    return bytesDecrypted;
}
} // namespace fragseal::crypto::backend

#endif // if defined(FRAGSEAL_USE_COMMONCRYPTO)
