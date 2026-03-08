#pragma once

#include <swift/bridging>

#include <cstdint>
#include <iomanip>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

using OptionalString = std::optional<std::string>;

enum class StorageBackend {
    s3,
    local,
};

enum class EncryptionMode {
    aes256Gcm,
    chacha20Poly1305,
    legacyAes128Cbc,
};

enum class KeyDerivationAlgorithm {
    pbkdf2Sha256,
};

struct SWIFT_UNCHECKED_SENDABLE BackupDescriptor {
    std::string id;
    std::string sourceName;
    std::string createdAt;
    std::int64_t chunkSize = 1;
    std::int64_t originalSize = 0;
    std::string originalSha256;

    BackupDescriptor() = default;

    BackupDescriptor(std::string id,
                     std::string sourceName,
                     std::string createdAt,
                     std::int64_t chunkSize,
                     std::int64_t originalSize,
                     std::string originalSha256) SWIFT_NAME(init(id:sourceName:createdAt:chunkSize:originalSize:originalSha256:))
        : id(std::move(id)),
          sourceName(std::move(sourceName)),
          createdAt(std::move(createdAt)),
          chunkSize(chunkSize),
          originalSize(originalSize),
          originalSha256(std::move(originalSha256)) {}
};

inline bool operator==(const BackupDescriptor &lhs, const BackupDescriptor &rhs) {
    return lhs.id == rhs.id
        && lhs.sourceName == rhs.sourceName
        && lhs.createdAt == rhs.createdAt
        && lhs.chunkSize == rhs.chunkSize
        && lhs.originalSize == rhs.originalSize
        && lhs.originalSha256 == rhs.originalSha256;
}

struct SWIFT_UNCHECKED_SENDABLE StorageDescriptor {
    StorageBackend backend = StorageBackend::local;
    OptionalString bucket;
    OptionalString region;
    std::string prefix;
    OptionalString rootPath;
    OptionalString endpoint;

    StorageDescriptor() = default;

    StorageDescriptor(StorageBackend backend,
                      OptionalString bucket,
                      OptionalString region,
                      std::string prefix,
                      OptionalString rootPath,
                      OptionalString endpoint) SWIFT_NAME(init(backend:bucket:region:prefix:rootPath:endpoint:))
        : backend(backend),
          bucket(std::move(bucket)),
          region(std::move(region)),
          prefix(std::move(prefix)),
          rootPath(std::move(rootPath)),
          endpoint(std::move(endpoint)) {}

    std::string manifestObjectKey() const SWIFT_COMPUTED_PROPERTY {
        return prefix + "/manifest.toml";
    }

    std::string chunkObjectKey(std::int64_t index) const SWIFT_NAME(chunkObjectKey(index:)) {
        std::ostringstream path;
        path << prefix << "/chunks/" << std::setw(8) << std::setfill('0') << index << ".bin";
        return path.str();
    }

    OptionalString localManifestPathString() const SWIFT_COMPUTED_PROPERTY {
        if (!rootPath.has_value() || rootPath->empty()) {
            return std::nullopt;
        }
        return *rootPath + "/" + manifestObjectKey();
    }
};

inline bool operator==(const StorageDescriptor &lhs, const StorageDescriptor &rhs) {
    return lhs.backend == rhs.backend
        && lhs.bucket == rhs.bucket
        && lhs.region == rhs.region
        && lhs.prefix == rhs.prefix
        && lhs.rootPath == rhs.rootPath
        && lhs.endpoint == rhs.endpoint;
}

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

struct SWIFT_UNCHECKED_SENDABLE BackupManifest {
    std::int64_t version = 1;
    BackupDescriptor backup;
    StorageDescriptor storage;
    EncryptionDescriptor encryption;
    ChunkList chunks;

    BackupManifest() = default;

    BackupManifest(std::int64_t version,
                   BackupDescriptor backup,
                   StorageDescriptor storage,
                   EncryptionDescriptor encryption,
                   ChunkList chunks) SWIFT_NAME(init(version:backup:storage:encryption:chunks:))
        : version(version),
          backup(std::move(backup)),
          storage(std::move(storage)),
          encryption(std::move(encryption)),
          chunks(std::move(chunks)) {}

    BackupManifest(BackupDescriptor backup,
                   StorageDescriptor storage,
                   EncryptionDescriptor encryption,
                   ChunkList chunks) SWIFT_NAME(init(backup:storage:encryption:chunks:))
        : BackupManifest(1, std::move(backup), std::move(storage), std::move(encryption), std::move(chunks)) {}
};

inline bool operator==(const BackupManifest &lhs, const BackupManifest &rhs) {
    return lhs.version == rhs.version
        && lhs.backup == rhs.backup
        && lhs.storage == rhs.storage
        && lhs.encryption == rhs.encryption
        && lhs.chunks == rhs.chunks;
}

inline OptionalString makeOptionalString(std::string value) {
    return OptionalString(std::move(value));
}

inline OptionalString makeNullOptionalString() {
    return std::nullopt;
}

inline constexpr std::string_view rawValue(StorageBackend backend) {
    switch (backend) {
    case StorageBackend::s3:
        return "s3";
    case StorageBackend::local:
        return "local";
    }
}

inline std::optional<StorageBackend> storageBackendFromRawValue(std::string_view value) {
    if (value == "s3") {
        return StorageBackend::s3;
    }
    if (value == "local") {
        return StorageBackend::local;
    }
    return std::nullopt;
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
