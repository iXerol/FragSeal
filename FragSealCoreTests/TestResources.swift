//
//  TestResources.swift
//  FragSealCoreTests
//

import Foundation

enum TestResources {
    private final class BundleMarker {}
    private static let bundle = Bundle(for: BundleMarker.self)

    static let legacyPlaintextURL = url(forResource: "legacy_plaintext", extension: "bin")
    static let legacyChunkURLs: [URL] = [
        url(forResource: "legacy_chunk_0", extension: "bin"),
        url(forResource: "legacy_chunk_1", extension: "bin"),
    ]

    static let legacyPassphrase = "fragseal-legacy-passphrase"
    static let legacyIterations: UInt32 = 600_000
    static let legacyKey = Data([
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
        0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
    ])
    static let legacyIVs = [
        Data([0x10, 0x32, 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe, 0xef, 0xcd, 0xab, 0x89, 0x67, 0x45, 0x23, 0x01]),
        Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10]),
    ]

    static func temporaryDirectory(named name: String = UUID().uuidString) -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func url(forResource name: String, extension ext: String?) -> URL {
        if let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }
        let fileName = ext.map { "\(name).\($0)" } ?? name
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("FragSealCoreTests/Resources")
                .appendingPathComponent(fileName),
        ]
        if let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }
        fatalError("Missing test resource \(fileName)")
    }
}
