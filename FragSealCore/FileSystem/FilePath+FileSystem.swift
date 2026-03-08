//
//  FilePath+FileSystem.swift
//  FragSealFileSystem
//
//  Created by Xerol Wong on 2024/01/03.
//

import System

public extension FilePath {
    private func withFileStatus<T>(
        followSymlink: Bool,
        _ body: (FileSystemStat) throws(Errno) -> T
    ) throws(Errno) -> T {
        var fileStatus = FileSystemStat()
        let result = string.withCString { pointer in
            let flags: Int32 = followSymlink ? 0 : Int32(FileSystemInterop.noFollowSymlinkFlag())
            return FileSystemInterop.fstatAt(
                dirfd: FileSystemInterop.atFdcwd(),
                path: pointer,
                fileStatus: &fileStatus,
                flags: flags
            )
        }
        guard result == 0 else {
            throw Errno(rawValue: FileSystemInterop.currentErrno())
        }
        return try body(fileStatus)
    }

    func exists() -> Bool {
        do {
            _ = try withFileStatus(followSymlink: false) { _ in true }
            return true
        } catch let error {
            switch error {
            case .noSuchFileOrDirectory, .notDirectory:
                return false
            default:
                return true
            }
        }
    }

    func isDirectory(followSymlink: Bool = true) -> Bool {
        do {
            return try withFileStatus(followSymlink: followSymlink) { fileStatus in
                FileSystemInterop.isDirectory(fileStatus)
            }
        } catch {
            return false
        }
    }

    func createDirectory(permissions: mode_t = 0o755, recursive: Bool = false) throws(Errno) {
        if recursive {
            let parent = removingLastComponent()
            if parent != self, !parent.isEmpty {
                if parent.exists() {
                    guard parent.isDirectory(followSymlink: true) else {
                        throw Errno.notDirectory
                    }
                } else {
                    try parent.createDirectory(permissions: permissions, recursive: true)
                }
            }
        }

        let result = string.withCString { pointer in
            FileSystemInterop.makeDirectory(pointer, permissions: permissions)
        }
        if result == 0 {
            return
        }

        let error = Errno(rawValue: FileSystemInterop.currentErrno())
        if error == .fileExists, isDirectory(followSymlink: true) {
            return
        }
        throw error
    }

    func isEmptyDirectory() async throws(Errno) -> Bool {
        for try await _ in directoryEntries() {
            return false
        }
        return true
    }

    func remove() throws {
        let result = string.withCString { pointer in
            FileSystemInterop.removePath(pointer)
        }
        guard result == 0 else {
            throw Errno(rawValue: FileSystemInterop.currentErrno())
        }
    }
}

extension FilePath {
    func directoryEntries() -> DirectoryEntries {
        DirectoryEntries(directory: self)
    }
}
