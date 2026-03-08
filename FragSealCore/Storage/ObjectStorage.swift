//
//  ObjectStorage.swift
//  FragSealCore
//

import Foundation

public enum TransferRetryDirective: Sendable {
    case stop
    case retry(after: Duration)
}

public protocol ObjectStorage: Sendable {
    func getObject(key: String) async throws -> Data
    func putObject(key: String, data: Data) async throws
    func retryDirective(for error: any Error, attempt: Int) -> TransferRetryDirective
}

public extension ObjectStorage {
    func retryDirective(for error: any Error, attempt: Int) -> TransferRetryDirective {
        .stop
    }
}

enum StorageError: Error {
    case invalidStorageDescriptor(StorageDescriptor)
    case unsupportedStorageBackend(StorageBackend)
}

enum ObjectStorageFactory {
    static func make(from descriptor: StorageDescriptor) throws -> any ObjectStorage {
        switch descriptor.backend {
        case .local:
            return try LocalObjectStorage(descriptor: descriptor)
        case .s3:
            return try S3ObjectStorage(descriptor: descriptor)
        @unknown default:
            throw StorageError.unsupportedStorageBackend(descriptor.backend)
        }
    }
}
