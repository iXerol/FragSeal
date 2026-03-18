#pragma once

#include "../include/LegacyAes128CbcCrypter.hpp"
#include "CryptoBackendConfig.hpp"
#include <memory>

namespace fragseal::crypto::backend {

namespace openssl_backend {
struct State;

std::shared_ptr<const State> create_state(
    const std::array<uint8_t, LegacyAes128CbcCrypter::blockSize> &key) noexcept;

OptionalSize decrypt(
    const State &state,
    ByteSpan iv,
    ByteSpan ciphertext,
    MutableByteSpan destination) noexcept;

} // namespace openssl_backend

namespace commoncrypto_backend {
struct State;

std::shared_ptr<const State> create_state(
    const std::array<uint8_t, LegacyAes128CbcCrypter::blockSize> &key) noexcept;

std::optional<size_t> decrypt(
    const State &state,
    ByteSpan iv,
    ByteSpan ciphertext,
    MutableByteSpan destination) noexcept;

} // namespace commoncrypto_backend

} // namespace fragseal::crypto::backend
