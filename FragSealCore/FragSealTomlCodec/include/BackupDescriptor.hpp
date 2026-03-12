#pragma once

#include <swift/bridging>

#include <cstdint>
#include <string>
#include <utility>

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
