#include "FragSealTomlCodec.hpp"

#include <cstdint>
#include <exception>
#include <limits>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>

#include "toml.hpp"

namespace {

TomlManifestEncodingResult encodeFailure(std::string_view message) noexcept {
    TomlManifestEncodingResult result;
    result.errorMessage = std::string(message);
    return result;
}

TomlManifestDecodingResult decodeFailure(std::string_view message) noexcept {
    TomlManifestDecodingResult result;
    result.errorMessage = std::string(message);
    return result;
}

bool validateNonNegative(std::int64_t value,
                         std::string_view fieldName,
                         std::string &errorOut) {
    if (value < 0) {
        errorOut = std::string(fieldName) + " must be non-negative";
        return false;
    }
    return true;
}

bool validatePositive(std::int64_t value,
                      std::string_view fieldName,
                      std::string &errorOut) {
    if (value <= 0) {
        errorOut = std::string(fieldName) + " must be positive";
        return false;
    }
    return true;
}

bool requireString(std::string_view value,
                   std::string_view fieldName,
                   std::string &errorOut) {
    if (value.empty()) {
        errorOut = std::string(fieldName) + " is missing";
        return false;
    }
    return true;
}

bool readRequiredString(const toml::table &table,
                        std::string_view key,
                        std::string_view fieldName,
                        std::string &destination,
                        std::string &errorOut) {
    const auto *node = table.get(key);
    if (node == nullptr) {
        errorOut = std::string(fieldName) + " is missing";
        return false;
    }

    const auto value = node->value<std::string_view>();
    if (!value.has_value()) {
        errorOut = std::string(fieldName) + " must be a string";
        return false;
    }

    destination.assign(*value);
    return requireString(destination, fieldName, errorOut);
}

bool readOptionalString(const toml::table &table,
                        std::string_view key,
                        OptionalString &destination,
                        std::string &errorOut) {
    const auto *node = table.get(key);
    if (node == nullptr) {
        destination.reset();
        return true;
    }

    const auto value = node->value<std::string_view>();
    if (!value.has_value()) {
        errorOut = std::string(key) + " must be a string";
        return false;
    }

    destination = std::string(*value);
    return true;
}

bool readRequiredInt64(const toml::table &table,
                       std::string_view key,
                       std::string_view fieldName,
                       std::int64_t &destination,
                       std::string &errorOut) {
    const auto *node = table.get(key);
    if (node == nullptr) {
        errorOut = std::string(fieldName) + " is missing";
        return false;
    }

    const auto value = node->value<std::int64_t>();
    if (!value.has_value()) {
        errorOut = std::string(fieldName) + " must be an integer";
        return false;
    }

    destination = *value;
    return true;
}

bool readRequiredUInt32(const toml::table &table,
                        std::string_view key,
                        std::string_view fieldName,
                        std::uint32_t &destination,
                        std::string &errorOut) {
    std::int64_t value = 0;
    if (!readRequiredInt64(table, key, fieldName, value, errorOut)) {
        return false;
    }

    if (value <= 0 || value > std::numeric_limits<std::uint32_t>::max()) {
        errorOut = std::string(fieldName) + " is out of range";
        return false;
    }

    destination = static_cast<std::uint32_t>(value);
    return true;
}

template <typename T>
const toml::table *requiredTable(const T &root,
                                 std::string_view key,
                                 std::string_view fieldName,
                                 std::string &errorOut) {
    const auto *node = root.get(key);
    if (node == nullptr) {
        errorOut = std::string(fieldName) + " is missing";
        return nullptr;
    }

    const auto *table = node->as_table();
    if (table == nullptr) {
        errorOut = std::string(fieldName) + " must be a table";
        return nullptr;
    }
    return table;
}

bool validateChunk(const ChunkDescriptor &chunk,
                   EncryptionMode mode,
                   std::string &errorOut) {
    if (!validateNonNegative(chunk.index, "chunks[index].index", errorOut)
        || !requireString(chunk.objectKey, "chunks[index].object_key", errorOut)
        || !validateNonNegative(chunk.offset, "chunks[index].offset", errorOut)
        || !validateNonNegative(chunk.plaintextSize, "chunks[index].plaintext_size", errorOut)
        || !validateNonNegative(chunk.ciphertextSize, "chunks[index].ciphertext_size", errorOut)) {
        return false;
    }

    if (mode == EncryptionMode::none) {
        return true;
    }

    if (!requireString(chunk.sha256, "chunks[index].sha256", errorOut)) {
        return false;
    }

    if (mode == EncryptionMode::legacyAes128Cbc) {
        if (!chunk.iv.has_value() || chunk.iv->empty()) {
            errorOut = "chunks[index].iv is missing";
            return false;
        }
    } else if (!chunk.nonce.has_value() || chunk.nonce->empty()) {
        errorOut = "chunks[index].nonce is missing";
        return false;
    }

    return true;
}

bool validateManifest(const BackupManifest &manifest, std::string &errorOut) {
    if (!validatePositive(manifest.version, "version", errorOut)
        || !requireString(manifest.backup.id, "backup.id", errorOut)
        || !requireString(manifest.backup.sourceName, "backup.source_name", errorOut)
        || !requireString(manifest.backup.createdAt, "backup.created_at", errorOut)
        || !validatePositive(manifest.backup.chunkSize, "backup.chunk_size", errorOut)
        || !validateNonNegative(manifest.backup.originalSize, "backup.original_size", errorOut)
        || manifest.storage.prefix.empty()) {
        if (errorOut.empty()) {
            errorOut = "storage.prefix is missing";
        }
        return false;
    }

    if (manifest.encryption.mode != EncryptionMode::none
        && !requireString(manifest.backup.originalSha256, "backup.original_sha256", errorOut)) {
        return false;
    }

    if (manifest.encryption.mode != EncryptionMode::none) {
        if (manifest.encryption.iterations == 0) {
            errorOut = "encryption.iterations must be positive";
            return false;
        }

        if (!requireString(manifest.encryption.salt, "encryption.salt", errorOut)
            || !requireString(manifest.encryption.wrappedKey, "encryption.wrapped_key", errorOut)) {
            return false;
        }
    }

    for (const auto &chunk : manifest.chunks) {
        if (!validateChunk(chunk, manifest.encryption.mode, errorOut)) {
            return false;
        }
    }

    return true;
}

bool parseBackup(const toml::table &table,
                 BackupDescriptor &backup,
                 std::string &errorOut) {
    OptionalString originalSha256;
    return readRequiredString(table, "id", "backup.id", backup.id, errorOut)
        && readRequiredString(table, "source_name", "backup.source_name", backup.sourceName, errorOut)
        && readRequiredString(table, "created_at", "backup.created_at", backup.createdAt, errorOut)
        && readRequiredInt64(table, "chunk_size", "backup.chunk_size", backup.chunkSize, errorOut)
        && validatePositive(backup.chunkSize, "backup.chunk_size", errorOut)
        && readRequiredInt64(table, "original_size", "backup.original_size", backup.originalSize, errorOut)
        && validateNonNegative(backup.originalSize, "backup.original_size", errorOut)
        && readOptionalString(table, "original_sha256", originalSha256, errorOut)
        && (backup.originalSha256 = originalSha256.value_or(""), true);
}

bool parseStorage(const toml::table &table,
                  StorageDescriptor &storage,
                  std::string &errorOut) {
    std::string backendValue;
    if (!readRequiredString(table, "backend", "storage.backend", backendValue, errorOut)) {
        return false;
    }

    const auto backend = storageBackendFromRawValue(backendValue);
    if (!backend.has_value()) {
        errorOut = "storage.backend is invalid";
        return false;
    }

    storage.backend = *backend;
    return readOptionalString(table, "bucket", storage.bucket, errorOut)
        && readOptionalString(table, "region", storage.region, errorOut)
        && readRequiredString(table, "prefix", "storage.prefix", storage.prefix, errorOut)
        && readOptionalString(table, "root_path", storage.rootPath, errorOut)
        && readOptionalString(table, "endpoint", storage.endpoint, errorOut);
}

bool parseEncryption(const toml::table &table,
                     EncryptionDescriptor &encryption,
                     std::string &errorOut) {
    if (table.empty()) {
        encryption.mode = EncryptionMode::none;
        encryption.kdf = KeyDerivationAlgorithm::pbkdf2Sha256;
        encryption.salt.clear();
        encryption.iterations = 1;
        encryption.wrappedKey.clear();
        return true;
    }

    std::string modeValue;
    if (!readRequiredString(table, "mode", "encryption.mode", modeValue, errorOut)) {
        return false;
    }
    const auto mode = encryptionModeFromRawValue(modeValue);
    if (!mode.has_value()) {
        errorOut = "encryption.mode is invalid";
        return false;
    }

    encryption.mode = *mode;
    if (*mode == EncryptionMode::none) {
        OptionalString kdfValue;
        if (!readOptionalString(table, "kdf", kdfValue, errorOut)) {
            return false;
        }
        if (kdfValue.has_value() && !kdfValue->empty()) {
            const auto parsed = keyDerivationAlgorithmFromRawValue(*kdfValue);
            if (!parsed.has_value()) {
                errorOut = "encryption.kdf is invalid";
                return false;
            }
            encryption.kdf = *parsed;
        } else {
            encryption.kdf = KeyDerivationAlgorithm::pbkdf2Sha256;
        }

        OptionalString maybeSalt;
        OptionalString maybeWrappedKey;
        std::uint32_t maybeIterations = 1;
        const auto *iterationsNode = table.get("iterations");
        const bool hasIterations = iterationsNode != nullptr;
        return readOptionalString(table, "salt", maybeSalt, errorOut)
            && readOptionalString(table, "wrapped_key", maybeWrappedKey, errorOut)
            && (!hasIterations || readRequiredUInt32(table, "iterations", "encryption.iterations", maybeIterations, errorOut))
            && (encryption.salt = maybeSalt.value_or(""), true)
            && (encryption.wrappedKey = maybeWrappedKey.value_or(""), true)
            && (encryption.iterations = maybeIterations, true);
    }

    std::string kdfValue;
    if (!readRequiredString(table, "kdf", "encryption.kdf", kdfValue, errorOut)) {
        return false;
    }
    const auto kdf = keyDerivationAlgorithmFromRawValue(kdfValue);
    if (!kdf.has_value()) {
        errorOut = "encryption.kdf is invalid";
        return false;
    }

    encryption.kdf = *kdf;
    return readRequiredString(table, "salt", "encryption.salt", encryption.salt, errorOut)
        && readRequiredUInt32(table, "iterations", "encryption.iterations", encryption.iterations, errorOut)
        && readRequiredString(table, "wrapped_key", "encryption.wrapped_key", encryption.wrappedKey, errorOut);
}

bool parseChunk(const toml::table &table,
                EncryptionMode mode,
                ChunkDescriptor &chunk,
                std::string &errorOut) {
    OptionalString chunkSha256;
    if (!readRequiredInt64(table, "index", "chunks[index].index", chunk.index, errorOut)
        || !readRequiredString(table, "object_key", "chunks[index].object_key", chunk.objectKey, errorOut)
        || !readRequiredInt64(table, "offset", "chunks[index].offset", chunk.offset, errorOut)
        || !readRequiredInt64(table, "plaintext_size", "chunks[index].plaintext_size", chunk.plaintextSize, errorOut)
        || !readRequiredInt64(table, "ciphertext_size", "chunks[index].ciphertext_size", chunk.ciphertextSize, errorOut)
        || (mode == EncryptionMode::none
                ? !readOptionalString(table, "sha256", chunkSha256, errorOut)
                : !readRequiredString(table, "sha256", "chunks[index].sha256", chunk.sha256, errorOut))
        || !readOptionalString(table, "nonce", chunk.nonce, errorOut)
        || !readOptionalString(table, "iv", chunk.iv, errorOut)) {
        return false;
    }

    if (mode == EncryptionMode::none) {
        chunk.sha256 = chunkSha256.value_or("");
    }

    return validateChunk(chunk, mode, errorOut);
}

void renderOptionalString(toml::table &table,
                          std::string_view key,
                          const OptionalString &value) {
    if (value.has_value()) {
        table.insert_or_assign(key, *value);
    }
}

} // namespace

TomlManifestEncodingResult TomlManifestCodecBridge::encode(const BackupManifest &manifest) noexcept {
    try {
        std::string error;
        if (!validateManifest(manifest, error)) {
            return encodeFailure(error);
        }

        toml::table document;
        document.insert_or_assign("version", manifest.version);

        toml::table backup;
        backup.insert_or_assign("id", manifest.backup.id);
        backup.insert_or_assign("source_name", manifest.backup.sourceName);
        backup.insert_or_assign("created_at", manifest.backup.createdAt);
        backup.insert_or_assign("chunk_size", manifest.backup.chunkSize);
        backup.insert_or_assign("original_size", manifest.backup.originalSize);
        if (!manifest.backup.originalSha256.empty()) {
            backup.insert_or_assign("original_sha256", manifest.backup.originalSha256);
        }
        document.insert_or_assign("backup", std::move(backup));

        toml::table storage;
        storage.insert_or_assign("backend", rawValue(manifest.storage.backend));
        renderOptionalString(storage, "bucket", manifest.storage.bucket);
        renderOptionalString(storage, "region", manifest.storage.region);
        storage.insert_or_assign("prefix", manifest.storage.prefix);
        renderOptionalString(storage, "root_path", manifest.storage.rootPath);
        renderOptionalString(storage, "endpoint", manifest.storage.endpoint);
        document.insert_or_assign("storage", std::move(storage));

        toml::table encryption;
        if (manifest.encryption.mode != EncryptionMode::none) {
            encryption.insert_or_assign("mode", rawValue(manifest.encryption.mode));
            encryption.insert_or_assign("kdf", rawValue(manifest.encryption.kdf));
            encryption.insert_or_assign("salt", manifest.encryption.salt);
            encryption.insert_or_assign("iterations", static_cast<std::int64_t>(manifest.encryption.iterations));
            encryption.insert_or_assign("wrapped_key", manifest.encryption.wrappedKey);
        }
        document.insert_or_assign("encryption", std::move(encryption));

        toml::array chunks;
        chunks.reserve(manifest.chunks.size());
        for (const auto &chunk : manifest.chunks) {
            toml::table chunkTable;
            chunkTable.insert_or_assign("index", chunk.index);
            chunkTable.insert_or_assign("object_key", chunk.objectKey);
            chunkTable.insert_or_assign("offset", chunk.offset);
            chunkTable.insert_or_assign("plaintext_size", chunk.plaintextSize);
            chunkTable.insert_or_assign("ciphertext_size", chunk.ciphertextSize);
            if (!chunk.sha256.empty()) {
                chunkTable.insert_or_assign("sha256", chunk.sha256);
            }
            renderOptionalString(chunkTable, "nonce", chunk.nonce);
            renderOptionalString(chunkTable, "iv", chunk.iv);
            chunks.push_back(std::move(chunkTable));
        }
        document.insert_or_assign("chunks", std::move(chunks));

        std::ostringstream stream;
        stream << document;
        TomlManifestEncodingResult result;
        result.isSuccess = true;
        result.toml = stream.str();
        return result;
    } catch (const std::bad_alloc &) {
        return encodeFailure("failed to render manifest");
    } catch (const std::exception &error) {
        return encodeFailure(error.what());
    }
}

TomlManifestDecodingResult TomlManifestCodecBridge::decode(const std::string &input) noexcept {
    try {
        BackupManifest manifest;
        const toml::table document = toml::parse(input);
        std::string error;

        if (!readRequiredInt64(document, "version", "version", manifest.version, error)
            || !validatePositive(manifest.version, "version", error)) {
            return decodeFailure(error);
        }

        const auto *backupTable = requiredTable(document, "backup", "backup", error);
        const auto *storageTable = requiredTable(document, "storage", "storage", error);
        const auto *encryptionTable = requiredTable(document, "encryption", "encryption", error);
        if (backupTable == nullptr || storageTable == nullptr || encryptionTable == nullptr) {
            return decodeFailure(error);
        }

        if (!parseBackup(*backupTable, manifest.backup, error)
            || !parseStorage(*storageTable, manifest.storage, error)
            || !parseEncryption(*encryptionTable, manifest.encryption, error)) {
            return decodeFailure(error);
        }

        manifest.chunks.clear();
        if (const auto *chunksNode = document.get("chunks")) {
            const auto *chunksArray = chunksNode->as_array();
            if (chunksArray == nullptr) {
                return decodeFailure("chunks must be an array");
            }

            manifest.chunks.reserve(chunksArray->size());
            for (const auto &entry : *chunksArray) {
                const auto *chunkTable = entry.as_table();
                if (chunkTable == nullptr) {
                    return decodeFailure("chunks entries must be tables");
                }

                manifest.chunks.emplace_back();
                if (!parseChunk(*chunkTable, manifest.encryption.mode, manifest.chunks.back(), error)) {
                    return decodeFailure(error);
                }
            }
        }

        if (!validateManifest(manifest, error)) {
            return decodeFailure(error);
        }

        TomlManifestDecodingResult result;
        result.isSuccess = true;
        result.manifest = std::move(manifest);
        return result;
    } catch (const toml::parse_error &error) {
        return decodeFailure(error.description());
    } catch (const std::bad_alloc &) {
        return decodeFailure("failed to parse manifest");
    } catch (const std::exception &error) {
        return decodeFailure(error.what());
    }
}
