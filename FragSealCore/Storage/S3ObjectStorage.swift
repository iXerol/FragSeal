//
//  S3ObjectStorage.swift
//  FragSealCore
//

import AWSS3
import AWSClientRuntime
import Foundation
import Smithy
import SmithyRetriesAPI

struct S3ObjectStorage: ObjectStorage {
    private let bucket: String
    private let client: S3Client

    init(descriptor: StorageDescriptor) throws {
        guard descriptor.backend == .s3,
              let bucket = descriptor.bucketValue,
              let region = descriptor.regionValue else {
            throw StorageError.invalidStorageDescriptor(descriptor)
        }

        var config = try S3Client.S3ClientConfig(
            region: region,
            endpoint: descriptor.endpointValue
        )
        if descriptor.endpointValue != nil {
            config.forcePathStyle = true
        }

        self.bucket = bucket
        client = S3Client(config: config)
    }

    func getObject(key: String) async throws -> Data {
        let output = try await client.getObject(
            input: GetObjectInput(bucket: bucket, key: key)
        )
        return try await output.body?.readData() ?? Data()
    }

    func putObject(key: String, data: Data) async throws {
        _ = try await client.putObject(
            input: PutObjectInput(
                body: ByteStream.data(data),
                bucket: bucket,
                key: key
            )
        )
    }

    func retryDirective(for error: any Error, attempt: Int) -> TransferRetryDirective {
        guard attempt < 4,
              let errorInfo = AWSRetryErrorInfoProvider.errorInfo(for: error) else {
            return .stop
        }

        switch errorInfo.errorType {
        case .transient, .throttling, .serverError:
            let delaySeconds = errorInfo.retryAfterHint ?? min(pow(2.0, Double(attempt - 1)) * 0.25, 2.0)
            return .retry(after: .seconds(delaySeconds))
        case .clientError:
            return .stop
        }
    }
}
