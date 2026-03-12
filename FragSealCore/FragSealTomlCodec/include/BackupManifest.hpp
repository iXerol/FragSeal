#pragma once

#include <swift/bridging>

#include <utility>

#include "BackupDescriptor.hpp"
#include "ChunkDescriptor.hpp"
#include "EncryptionDescriptor.hpp"
#include "StorageDescriptor.hpp"

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
