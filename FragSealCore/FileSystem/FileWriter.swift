//
//  FileWriter.swift
//  FragSealFileSystem
//
//  Created by Xerol Wong on 2024/01/09.
//

import System

public struct FileWriter: ~Copyable {
    public enum OpenMode {
        case truncate
        case createNew
    }

    private let fd: FileDescriptor

    public init(path: FilePath,
                mode: OpenMode = .truncate,
                permissions: FilePermissions = .init(rawValue: 0o644)) throws {
        let openOptions: FileDescriptor.OpenOptions = switch mode {
        case .truncate: [.create, .truncate]
        case .createNew: [.create, .exclusiveCreate]
        }
        fd = try FileDescriptor.open(
            path,
            .writeOnly,
            options: openOptions,
            permissions: permissions
        )
    }

    public func append(_ collection: some Collection<UInt8>) throws {
        let bytesWritten = try fd.writeAll(collection)
        guard bytesWritten == collection.count else {
            throw FileError.didNotWriteAllData
        }
    }

    public func append(from source: consuming FileDescriptor,
                       chunkSize: Int = 1_000_000) throws -> Int {
        try source.closeAfter {
            guard chunkSize > 0 else {
                throw FileError.invalidChunkSize(chunkSize)
            }

            var totalBytesCopied = 0
            try source.withReadChunks(chunkSize: chunkSize) { chunk in
                totalBytesCopied += chunk.count
                let bytesWritten = try fd.writeAll(chunk)

                guard bytesWritten == chunk.count else {
                    throw FileError.didNotWriteAllData
                }
            }

            return totalBytesCopied
        }
    }

    deinit {
        try? fd.close()
    }
}

public extension FileWriter {
    enum FileError: Error, Equatable {
        case didNotWriteAllData
        case invalidChunkSize(Int)
    }
}

private extension FileDescriptor {
    func withReadChunks(chunkSize: Int,
                        _ body: (UnsafeRawBufferPointer) throws -> Void) throws {
        guard chunkSize > 0 else {
            throw Errno.invalidArgument
        }

        var buffer = [UInt8](repeating: 0, count: chunkSize)
        try buffer.withUnsafeMutableBytes { rawBuffer in
            let readableBuffer = UnsafeRawBufferPointer(rawBuffer)
            while true {
                let bytesRead = try read(into: rawBuffer)
                guard bytesRead > 0 else {
                    break
                }

                let chunk = UnsafeRawBufferPointer(rebasing: readableBuffer[..<bytesRead])
                try body(chunk)
            }
        }
    }
}
