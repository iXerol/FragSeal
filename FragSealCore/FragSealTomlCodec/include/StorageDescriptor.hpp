#pragma once

#include <swift/bridging>

#include <cstdint>
#include <iomanip>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>

#include "ManifestOptionalString.hpp"

enum class StorageBackend {
    s3,
    local,
};

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
