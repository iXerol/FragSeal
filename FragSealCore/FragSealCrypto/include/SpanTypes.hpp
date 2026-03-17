//
//  SpanTypes.hpp
//  FragSealCrypto
//

#pragma once

#include <cstdint>
#include <optional>
#include <span>

using ByteSpan = std::span<const uint8_t>;
using MutableByteSpan = std::span<uint8_t>;

using OptionalSize = std::optional<size_t>;
