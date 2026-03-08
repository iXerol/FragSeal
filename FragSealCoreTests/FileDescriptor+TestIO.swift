//
//  FileDescriptor+TestIO.swift
//  FragSealCoreTests
//

import Foundation
import System

extension FileDescriptor {
    func readToEndData(chunkSize: Int = 8192) throws -> Data {
        guard chunkSize > 0 else {
            throw Errno.invalidArgument
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: chunkSize)

        try buffer.withUnsafeMutableBytes { rawBuffer in
            let readableBuffer = UnsafeRawBufferPointer(rawBuffer)
            while true {
                let bytesRead = try read(into: rawBuffer)
                guard bytesRead > 0 else {
                    break
                }

                data.append(contentsOf: readableBuffer[..<bytesRead])
            }
        }

        return data
    }

    func hasReadableByte() throws -> Bool {
        var buffer = [UInt8](repeating: 0, count: 1)
        return try buffer.withUnsafeMutableBytes { rawBuffer in
            try read(into: rawBuffer) > 0
        }
    }
}
