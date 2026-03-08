import Glibc
import Testing

@main
enum LinuxTestMain {
    static func main() async {
        let exitCode: CInt = await Testing.__swiftPMEntryPoint()
        exit(exitCode)
    }
}
