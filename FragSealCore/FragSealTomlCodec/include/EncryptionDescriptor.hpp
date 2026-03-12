#pragma once

#include <swift/bridging>

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <utility>

enum class EncryptionMode {
    aes256Gcm,
    chacha20Poly1305,
    legacyAes128Cbc,
};

enum class KeyDerivationAlgorithm {
    pbkdf2Sha256,
};

struct SWIFT_UNCHECKED_SENDABLE EncryptionDescriptor {
    EncryptionMode mode = EncryptionMode::aes256Gcm;
    KeyDerivationAlgorithm kdf = KeyDerivationAlgorithm::pbkdf2Sha256;
    std::string salt;
    std::uint32_t iterations = 1;
    std::string wrappedKey;

    EncryptionDescriptor() = default;

    EncryptionDescriptor(EncryptionMode mode,
                         KeyDerivationAlgorithm kdf,
                         std::string salt,
                         std::uint32_t iterations,
                         std::string wrappedKey) SWIFT_NAME(init(mode:kdf:salt:iterations:wrappedKey:))
        : mode(mode),
          kdf(kdf),
          salt(std::move(salt)),
          iterations(iterations),
          wrappedKey(std::move(wrappedKey)) {}

    EncryptionDescriptor(EncryptionMode mode,
                         std::string salt,
                         std::uint32_t iterations,
                         std::string wrappedKey) SWIFT_NAME(init(mode:salt:iterations:wrappedKey:))
        : EncryptionDescriptor(
              mode,
              KeyDerivationAlgorithm::pbkdf2Sha256,
              std::move(salt),
              iterations,
              std::move(wrappedKey)) {}
};

inline bool operator==(const EncryptionDescriptor &lhs, const EncryptionDescriptor &rhs) {
    return lhs.mode == rhs.mode
        && lhs.kdf == rhs.kdf
        && lhs.salt == rhs.salt
        && lhs.iterations == rhs.iterations
        && lhs.wrappedKey == rhs.wrappedKey;
}

inline constexpr std::string_view rawValue(EncryptionMode mode) {
    switch (mode) {
    case EncryptionMode::aes256Gcm:
        return "aes-256-gcm";
    case EncryptionMode::chacha20Poly1305:
        return "chacha20-poly1305";
    case EncryptionMode::legacyAes128Cbc:
        return "legacy-aes-128-cbc";
    }
}

inline std::string encryptionModeRawValueString(EncryptionMode mode) {
    return std::string(rawValue(mode));
}

inline std::optional<EncryptionMode> encryptionModeFromRawValue(std::string_view value) {
    if (value == "aes-256-gcm") {
        return EncryptionMode::aes256Gcm;
    }
    if (value == "chacha20-poly1305") {
        return EncryptionMode::chacha20Poly1305;
    }
    if (value == "legacy-aes-128-cbc") {
        return EncryptionMode::legacyAes128Cbc;
    }
    return std::nullopt;
}

inline constexpr std::int64_t encryptionModeKeySize(EncryptionMode mode) {
    switch (mode) {
    case EncryptionMode::legacyAes128Cbc:
        return 16;
    case EncryptionMode::aes256Gcm:
    case EncryptionMode::chacha20Poly1305:
        return 32;
    }
}

inline constexpr std::int64_t encryptionModeNonceSize(EncryptionMode mode) {
    switch (mode) {
    case EncryptionMode::legacyAes128Cbc:
        return 16;
    case EncryptionMode::aes256Gcm:
    case EncryptionMode::chacha20Poly1305:
        return 12;
    }
}

inline constexpr bool encryptionModeIsWritable(EncryptionMode mode) {
    return mode != EncryptionMode::legacyAes128Cbc;
}

inline constexpr std::string_view rawValue(KeyDerivationAlgorithm algorithm) {
    switch (algorithm) {
    case KeyDerivationAlgorithm::pbkdf2Sha256:
        return "pbkdf2-sha256";
    }
}

inline std::string keyDerivationAlgorithmRawValueString(KeyDerivationAlgorithm algorithm) {
    return std::string(rawValue(algorithm));
}

inline std::optional<KeyDerivationAlgorithm> keyDerivationAlgorithmFromRawValue(std::string_view value) {
    if (value == "pbkdf2-sha256") {
        return KeyDerivationAlgorithm::pbkdf2Sha256;
    }
    return std::nullopt;
}
