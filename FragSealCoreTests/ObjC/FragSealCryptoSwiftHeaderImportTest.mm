//
//  FragSealCryptoSwiftHeaderImportTest.mm
//  FragSealCoreTests
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <FragSealCrypto/FragSealCrypto.h>
#include <array>
#include <span>

@interface FragSealCryptoSwiftHeaderImportTest : XCTestCase
@end

@implementation FragSealCryptoSwiftHeaderImportTest

- (void)testLegacyAes128CbcCrypterInitArray {
    XCTAssertEqual(kLegacyAes128CbcBlockSize, static_cast<size_t>(LegacyAes128CbcCrypter::blockSize));

    std::array<uint8_t, LegacyAes128CbcCrypter::blockSize> key{};
    LegacyAes128CbcCrypter crypter(key);
    auto method = &LegacyAes128CbcCrypter::decrypt;
    XCTAssertTrue(method != nullptr);
}

- (void)testLegacyAes128CbcCrypterInitSpan {
    XCTAssertEqual(kLegacyAes128CbcBlockSize, static_cast<size_t>(LegacyAes128CbcCrypter::blockSize));

    std::array<uint8_t, LegacyAes128CbcCrypter::blockSize> key{};
    std::span<uint8_t, LegacyAes128CbcCrypter::blockSize> keySpan(key);
    LegacyAes128CbcCrypter crypter(keySpan);
    auto method = &LegacyAes128CbcCrypter::decrypt;
    XCTAssertTrue(method != nullptr);
}

@end
