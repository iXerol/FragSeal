//
//  Type+ExpressibleByArgument.swift
//  FragSeal
//
//  Created by Xerol Wong on 2023/08/04.
//

import ArgumentParser
import Foundation
import System
import FragSealCore

extension URL: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        if let url = URL(string: argument) {
            self = url
        } else {
            return nil
        }
    }
}

extension FilePath: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }
}

extension EncryptionMode: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        switch argument {
        case "none":
            self = .none
        case "aes-256-gcm":
            self = .aes256Gcm
        case "chacha20-poly1305":
            self = .chacha20Poly1305
        case "legacy-aes-128-cbc":
            self = .legacyAes128Cbc
        default:
            return nil
        }
    }
}
