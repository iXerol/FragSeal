#pragma once

#include <swift/bridging>

#include <string>

#include "FragSealManifestModel.hpp"

struct SWIFT_UNCHECKED_SENDABLE TomlManifestEncodingResult {
    bool isSuccess = false;
    std::string toml;
    std::string errorMessage;
};

struct SWIFT_UNCHECKED_SENDABLE TomlManifestDecodingResult {
    bool isSuccess = false;
    BackupManifest manifest;
    std::string errorMessage;
};

struct TomlManifestCodecBridge {
    static TomlManifestEncodingResult encode(const BackupManifest &manifest) noexcept SWIFT_NAME(encode(_:));
    static TomlManifestDecodingResult decode(const std::string &input) noexcept SWIFT_NAME(decode(_:));
};
