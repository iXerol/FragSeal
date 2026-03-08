#pragma once

#include <swift/bridging>

#include <cstdint>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

struct FileSystemInterop {
    using FileStatus = struct stat;
    using DirectoryHandle = void *;

    static int currentErrno() noexcept;
    static int atFdcwd() noexcept;
    static int noFollowSymlinkFlag() noexcept;
    static int fstatAt(
        int dirfd,
        const char *path,
        FileStatus *fileStatus,
        int flags
    ) noexcept SWIFT_NAME(fstatAt(dirfd:path:fileStatus:flags:));
    static bool isDirectory(const FileStatus &fileStatus) noexcept SWIFT_NAME(isDirectory(_:));
    static int makeDirectory(const char *path, mode_t permissions) noexcept SWIFT_NAME(makeDirectory(_:permissions:));
    static int removePath(const char *path) noexcept SWIFT_NAME(removePath(_:));
    static DirectoryHandle openDirectory(const char *path) noexcept SWIFT_NAME(openDirectory(_:));
    static int closeDirectory(DirectoryHandle directory) noexcept SWIFT_NAME(closeDirectory(_:));
    static int readDirectoryEntryName(
        DirectoryHandle directory,
        const char **nameOut
    ) noexcept SWIFT_NAME(readDirectoryEntryName(_:nameOut:));
};

using FileSystemStat = FileSystemInterop::FileStatus;

inline int FileSystemInterop::currentErrno() noexcept {
    return errno;
}

inline int FileSystemInterop::atFdcwd() noexcept {
    return AT_FDCWD;
}

inline int FileSystemInterop::noFollowSymlinkFlag() noexcept {
    return AT_SYMLINK_NOFOLLOW;
}

inline int FileSystemInterop::fstatAt(
    int dirfd,
    const char *path,
    FileStatus *fileStatus,
    int flags
) noexcept {
    return fstatat(dirfd, path, fileStatus, flags);
}

inline bool FileSystemInterop::isDirectory(const FileStatus &fileStatus) noexcept {
    return S_ISDIR(fileStatus.st_mode);
}

inline int FileSystemInterop::makeDirectory(const char *path, mode_t permissions) noexcept {
    return mkdir(path, permissions);
}

inline int FileSystemInterop::removePath(const char *path) noexcept {
    return remove(path);
}

inline FileSystemInterop::DirectoryHandle FileSystemInterop::openDirectory(const char *path) noexcept {
    return opendir(path);
}

inline int FileSystemInterop::closeDirectory(DirectoryHandle directory) noexcept {
    return closedir(static_cast<DIR *>(directory));
}

inline int FileSystemInterop::readDirectoryEntryName(
    DirectoryHandle directory,
    const char **nameOut
) noexcept {
    errno = 0;
    dirent *entry = readdir(static_cast<DIR *>(directory));
    if (entry == nullptr) {
        *nameOut = nullptr;
        return errno == 0 ? 0 : -1;
    }
    *nameOut = entry->d_name;
    return 1;
}
