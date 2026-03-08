//
//  LocalObjectStorage.swift
//  FragSealCore
//

import Foundation
import System
import FragSealFileSystem

struct LocalObjectStorage: ObjectStorage {
    private let rootPath: FilePath

    init(descriptor: StorageDescriptor) throws {
        guard let rootPath = descriptor.rootPathValue else {
            throw StorageError.invalidStorageDescriptor(descriptor)
        }
        self.rootPath = FilePath(rootPath)
    }

    func getObject(key: String) async throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: absolutePath(for: key).string))
    }

    func putObject(key: String, data: Data) async throws {
        let path = absolutePath(for: key)
        try path.removingLastComponent().createDirectory(recursive: true)
        let writer = try FileWriter(path: path, mode: .truncate)
        try writer.append(data)
    }

    private func absolutePath(for key: String) -> FilePath {
        rootPath.appending(key)
    }
}
