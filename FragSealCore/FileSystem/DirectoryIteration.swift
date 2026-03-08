//
//  DirectoryIteration.swift
//  FragSealFileSystem
//
//  Created by Xerol Wong on 2026/03/07.
//

import System

private enum DirectoryInterop {
    typealias Handle = UnsafeMutableRawPointer

    static func open(at path: FilePath) throws(Errno) -> Handle {
        let handle = path.string.withCString { pointer in
            FileSystemInterop.openDirectory(pointer)
        }
        guard let handle else {
            throw Errno(rawValue: FileSystemInterop.currentErrno())
        }
        return handle
    }

    static func close(_ handle: Handle) {
        _ = FileSystemInterop.closeDirectory(handle)
    }

    static func readEntryName(from handle: Handle) throws(Errno) -> String? {
        var namePointer: UnsafePointer<CChar>?
        switch FileSystemInterop.readDirectoryEntryName(handle, nameOut: &namePointer) {
        case 1:
            guard let namePointer else {
                return nil
            }
            return String(cString: namePointer)
        case 0:
            return nil
        default:
            throw Errno(rawValue: FileSystemInterop.currentErrno())
        }
    }
}

struct DirectoryEntries: AsyncSequence {
    typealias Element = FilePath
    typealias Failure = Errno

    let directory: FilePath

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(directory: directory)
    }

    final class AsyncIterator: AsyncIteratorProtocol {
        typealias Element = FilePath
        typealias Failure = Errno

        private let directory: FilePath
        private var stream: DirectoryStream?

        init(directory: FilePath) {
            self.directory = directory
        }

        func next() async throws(Errno) -> FilePath? {
            if stream == nil {
                stream = try DirectoryStream(opening: directory)
            }
            guard let stream else {
                return nil
            }

            let entry = try stream.nextEntry(in: directory)
            if entry == nil {
                self.stream = nil
            }
            return entry
        }
    }
}

struct DirectoryStream {
    private final class HandleBox {
        let handle: DirectoryInterop.Handle

        init(handle: DirectoryInterop.Handle) {
            self.handle = handle
        }

        deinit {
            DirectoryInterop.close(handle)
        }
    }

    private let handleBox: HandleBox

    init(opening path: FilePath) throws(Errno) {
        handleBox = HandleBox(handle: try DirectoryInterop.open(at: path))
    }

    func nextEntry(in directory: FilePath) throws(Errno) -> FilePath? {
        while let name = try DirectoryInterop.readEntryName(from: handleBox.handle) {
            if name != "." && name != ".." {
                return directory.appending(name)
            }
        }
        return nil
    }
}
