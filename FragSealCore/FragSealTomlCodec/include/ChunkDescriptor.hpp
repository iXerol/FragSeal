#pragma once

#include <swift/bridging>

#include <cstdint>
#include <string>
#include <utility>
#include <vector>

#include "EncryptionDescriptor.hpp"
#include "ManifestOptionalString.hpp"

struct SWIFT_UNCHECKED_SENDABLE ChunkDescriptor {
    std::int64_t index = 0;
    std::string objectKey;
    std::int64_t offset = 0;
    std::int64_t plaintextSize = 0;
    std::int64_t ciphertextSize = 0;
    std::string sha256;
    OptionalString nonce;
    OptionalString iv;

    ChunkDescriptor() = default;

    ChunkDescriptor(std::int64_t index,
                    std::string objectKey,
                    std::int64_t offset,
                    std::int64_t plaintextSize,
                    std::int64_t ciphertextSize,
                    std::string sha256,
                    OptionalString nonce,
                    OptionalString iv) SWIFT_NAME(init(index:objectKey:offset:plaintextSize:ciphertextSize:sha256:nonce:iv:))
        : index(index),
          objectKey(std::move(objectKey)),
          offset(offset),
          plaintextSize(plaintextSize),
          ciphertextSize(ciphertextSize),
          sha256(std::move(sha256)),
          nonce(std::move(nonce)),
          iv(std::move(iv)) {}

    OptionalString nonceOrIVBase64(EncryptionMode mode) const SWIFT_NAME(nonceOrIVBase64(for:)) {
        switch (mode) {
        case EncryptionMode::none:
            return std::nullopt;
        case EncryptionMode::legacyAes128Cbc:
            return iv;
        case EncryptionMode::aes256Gcm:
        case EncryptionMode::chacha20Poly1305:
            return nonce;
        }
    }
};

inline bool operator==(const ChunkDescriptor &lhs, const ChunkDescriptor &rhs) {
    return lhs.index == rhs.index
        && lhs.objectKey == rhs.objectKey
        && lhs.offset == rhs.offset
        && lhs.plaintextSize == rhs.plaintextSize
        && lhs.ciphertextSize == rhs.ciphertextSize
        && lhs.sha256 == rhs.sha256
        && lhs.nonce == rhs.nonce
        && lhs.iv == rhs.iv;
}

using ChunkList = std::vector<ChunkDescriptor>;
