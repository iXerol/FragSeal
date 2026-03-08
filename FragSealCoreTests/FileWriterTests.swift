//
//  FileWriterTests.swift
//  FragSealCoreTests
//

import Foundation
import System
import Testing
@testable import FragSealCore

@Suite
struct FileWriterTests {
    @Test
    func writeOverwritesExistingFile() throws {
        let filePath = temporaryFilePath(prefix: "filewriter-overwrite")
        defer {
            try? filePath.remove()
        }

        let firstData = Data([0x01, 0x02, 0x03, 0x04])
        let secondData = Data([0xAA, 0xBB])

        let firstWriter = try FileWriter(path: filePath, mode: .truncate)
        try firstWriter.append(firstData)

        let secondWriter = try FileWriter(path: filePath, mode: .truncate)
        try secondWriter.append(secondData)

        #expect(try readData(at: filePath) == secondData)
    }

    @Test
    func copyContentsCopiesEntireSourceFile() throws {
        let sourcePath = temporaryFilePath(prefix: "filewriter-source")
        let destinationPath = temporaryFilePath(prefix: "filewriter-destination")
        defer {
            try? sourcePath.remove()
            try? destinationPath.remove()
        }

        let sourceData = Data((0 ..< 2048).map { UInt8($0 % 251) })
        let sourceWriter = try FileWriter(path: sourcePath, mode: .truncate)
        try sourceWriter.append(sourceData)

        let sourceFd = try FileDescriptor.open(sourcePath, .readOnly)
        let destinationWriter = try FileWriter(path: destinationPath, mode: .truncate)
        let copiedBytes = try destinationWriter.append(from: sourceFd, chunkSize: 37)
        #expect(copiedBytes == sourceData.count)
        #expect(try readData(at: destinationPath) == sourceData)
    }

    @Test
    func copyContentsRejectsInvalidChunkSize() throws {
        let sourcePath = temporaryFilePath(prefix: "filewriter-invalid-source")
        let destinationPath = temporaryFilePath(prefix: "filewriter-invalid-destination")
        defer {
            try? sourcePath.remove()
            try? destinationPath.remove()
        }

        let sourceWriter = try FileWriter(path: sourcePath, mode: .truncate)
        try sourceWriter.append(Data([0x01, 0x02, 0x03]))
        let sourceFd = try FileDescriptor.open(sourcePath, .readOnly)
        let destinationWriter = try FileWriter(path: destinationPath, mode: .truncate)

        do {
            _ = try destinationWriter.append(from: sourceFd, chunkSize: 0)
            Issue.record("Expected invalid chunk size to throw")
        } catch let error as FileWriter.FileError {
            #expect(error == .invalidChunkSize(0))
        }
    }

    @Test
    func createNewThrowsWhenFileAlreadyExists() throws {
        let filePath = temporaryFilePath(prefix: "filewriter-create-new")
        defer {
            try? filePath.remove()
        }

        let initialWriter = try FileWriter(path: filePath, mode: .truncate)
        try initialWriter.append(Data([0x01]))

        do {
            _ = try FileWriter(path: filePath, mode: .createNew)
            Issue.record("Expected createNew to fail when destination exists")
        } catch let error as Errno {
            #expect(error == .fileExists)
        }
    }
}

private func temporaryFilePath(prefix: String) -> FilePath {
    FilePath(FileManager.default.temporaryDirectory.path)
        .appending("\(prefix)-\(UUID().uuidString).bin")
}

private func readData(at path: FilePath, chunkSize: Int = 512) throws -> Data {
    let descriptor = try FileDescriptor.open(path, .readOnly)
    return try descriptor.closeAfter {
        try descriptor.readToEndData(chunkSize: chunkSize)
    }
}
