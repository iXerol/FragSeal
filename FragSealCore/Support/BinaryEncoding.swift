//
//  BinaryEncoding.swift
//  FragSealCore
//

import Foundation

extension Data {
    init(base64EncodedOrThrow string: String) throws {
        guard let data = Data(base64Encoded: string) else {
            throw BinaryEncodingError.invalidBase64(string)
        }
        self = data
    }

    var base64EncodedStringValue: String {
        base64EncodedString()
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

enum BinaryEncodingError: Error {
    case invalidBase64(String)
}
