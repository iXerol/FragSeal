import Cxx
import CxxStdlib
import Foundation

public extension std.string {
    var stringValue: String {
        String(self)
    }
}

public extension OptionalString {
    init(_ value: String?) {
        if let value {
            self = makeOptionalString(std.string(value))
        } else {
            self = makeNullOptionalString()
        }
    }

    var stringValue: String? {
        Optional(fromCxx: self).map(String.init)
    }
}

public enum TomlManifestCodec {
    public enum Error: Swift.Error {
        case invalidEncoding
        case codec(String)
    }

    public static func encode(_ manifest: BackupManifest) throws -> Data {
        let result = TomlManifestCodecBridge.encode(manifest)
        guard result.isSuccess else {
            throw Error.codec(result.errorMessage.stringValue)
        }
        return Data(result.toml.stringValue.utf8)
    }

    public static func decode(_ data: Data) throws -> BackupManifest {
        guard let input = String(data: data, encoding: .utf8) else {
            throw Error.invalidEncoding
        }

        let result = TomlManifestCodecBridge.decode(std.string(input))
        guard result.isSuccess else {
            throw Error.codec(result.errorMessage.stringValue)
        }
        return result.manifest
    }
}
