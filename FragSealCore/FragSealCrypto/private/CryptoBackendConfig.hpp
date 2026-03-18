#pragma once

#if defined(FRAGSEAL_USE_COMMONCRYPTO)
#if !defined(__APPLE__)
#error "FRAGSEAL_USE_COMMONCRYPTO is only supported on Apple platforms."
#endif
#include <CommonCrypto/CommonCrypto.h>
#endif

#if defined(FRAGSEAL_USE_OPENSSL) && !defined(FRAGSEAL_ENABLE_OPENSSL)
#define FRAGSEAL_ENABLE_OPENSSL
#endif
