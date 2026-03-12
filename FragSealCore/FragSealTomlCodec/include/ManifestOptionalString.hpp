#pragma once

#include <optional>
#include <string>

using OptionalString = std::optional<std::string>;

inline OptionalString makeOptionalString(std::string value) {
    return OptionalString(std::move(value));
}

inline OptionalString makeNullOptionalString() {
    return std::nullopt;
}
