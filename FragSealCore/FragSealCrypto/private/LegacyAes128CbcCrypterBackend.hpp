#pragma once

#include "../include/LegacyAes128CbcCrypter.hpp"
#include "CryptoBackendConfig.hpp"
#include <memory>

namespace fragseal::crypto::backend {

struct State;

std::shared_ptr<const State> create_state(
    const std::array<uint8_t, LegacyAes128CbcCrypter::blockSize> &key) noexcept;

std::optional<size_t> decrypt(
    const State &state,
    LegacyAes128CbcCrypter::ByteSpan iv,
    LegacyAes128CbcCrypter::ByteSpan ciphertext,
    LegacyAes128CbcCrypter::MutableByteSpan destination) noexcept;

} // namespace fragseal::crypto::backend
