//
//  FragSeal.swift
//  FragSeal
//

import ArgumentParser
import Foundation
import System
import FragSealCore

@main
struct FragSeal: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fragseal",
        abstract: "Single-file backup uploads and restores backed by TOML manifests.",
        subcommands: [
            Upload.self,
            Download.self,
        ],
        defaultSubcommand: Upload.self
    )
}

extension FragSeal {
    struct Upload: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Optionally encrypt, chunk, and upload a file.")

        @Option(name: [.long, .short], help: "Input file to back up.")
        var input: FilePath

        @Option(name: [.long, .short], help: "Path to the local TOML manifest to write.")
        var manifest: FilePath

        @Option(name: [.customLong("storage-uri")], help: "Storage URI, for example s3://bucket/prefix or file:///tmp/fragseal.")
        var storageURI: URL

        @Option(name: [.long], help: "Chunk encryption algorithm.")
        var algorithm: EncryptionMode?

        @Option(name: [.customLong("chunk-size")], help: "Chunk size in bytes.")
        var chunkSize: Int = 64 * 1024 * 1024

        @Option(name: [.long], help: "AWS region override for S3 storage.")
        var region: String?

        @Option(name: [.long], help: "Custom S3 endpoint override.")
        var endpoint: URL?

        private mutating func resolveAlgorithm() throws -> EncryptionMode {
            if let algorithm {
                return algorithm
            }

            guard PassphraseReader.isInteractiveStdin() else {
                throw ValidationError("Missing --algorithm in non-interactive mode. Specify one of: none, aes-256-gcm, chacha20-poly1305.")
            }

            print("Select algorithm (none | aes-256-gcm | chacha20-poly1305) [none]: ", terminator: "")
            let selection = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if selection.isEmpty {
                return .none
            }
            guard let parsed = EncryptionMode(argument: selection) else {
                throw ValidationError("Invalid algorithm '\(selection)'. Expected: none, aes-256-gcm, chacha20-poly1305.")
            }
            return parsed
        }

        mutating func run() async throws {
            let selectedAlgorithm = try resolveAlgorithm()
            let passphrase = selectedAlgorithm == .none ? nil : try PassphraseReader.resolve(confirm: true)
            let uploader = BackupUploader()
            let manifest = try await uploader.upload(
                input: input,
                manifestPath: manifest,
                storageURI: storageURI,
                algorithm: selectedAlgorithm,
                chunkSize: chunkSize,
                region: region,
                endpoint: endpoint,
                passphrase: passphrase
            )
            print("Uploaded backup \(manifest.backup.id) with \(manifest.chunks.count) chunks.")
        }
    }

    struct Download: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Restore a file from a TOML manifest.")

        @Option(name: [.long, .short], help: "Path to the local TOML manifest to read.")
        var manifest: FilePath

        @Option(name: [.long, .short], help: "Destination file path.")
        var output: FilePath

        mutating func run() async throws {
            let manifestModel = try TomlManifestCodec.read(from: manifest)
            let passphrase = manifestModel.encryption.mode == .none ? nil : try PassphraseReader.resolve()
            let downloader = BackupDownloader()
            try await downloader.download(
                manifestPath: manifest,
                output: output,
                passphrase: passphrase
            )
            print("Restored backup to \(output.string)")
        }
    }
}
