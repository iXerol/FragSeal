//
//  Retry.swift
//  FragSealCore
//

func retry<T>(
    _ label: String = "\(#fileID):\(#line)",
    _ operation: @Sendable @escaping () async throws -> T,
    when condition: @Sendable @escaping (_ error: any Error, _ attempt: Int) async -> TransferRetryDirective
) async throws -> T {
    var attempt = 1

    while true {
        do {
            try Task.checkCancellation()
            return try await operation()
        } catch {
            let directive = await condition(error, attempt)
            guard case let .retry(delay) = directive else {
                throw error
            }

            print("Retrying \(label) after attempt \(attempt) in \(delay): \(error)")
            try await Task.sleep(for: delay)
            attempt += 1
        }
    }
}
