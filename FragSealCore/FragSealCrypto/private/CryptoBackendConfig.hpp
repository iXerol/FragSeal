#pragma once

#if (defined(FRAGSEAL_USE_COMMONCRYPTO) ? 1 : 0) + \
    (defined(FRAGSEAL_USE_OPENSSL) ? 1 : 0) > 1
#error "Only one legacy AES-128-CBC backend may be defined at a time."
#endif

#if !defined(FRAGSEAL_USE_COMMONCRYPTO) && !defined(FRAGSEAL_USE_OPENSSL)
#if defined(__APPLE__)
#define FRAGSEAL_USE_COMMONCRYPTO
#else
#define FRAGSEAL_USE_OPENSSL
#endif
#endif

#if defined(FRAGSEAL_USE_COMMONCRYPTO)
#include <CommonCrypto/CommonCrypto.h>
#elif !defined(FRAGSEAL_USE_OPENSSL)
#error "No legacy AES-128-CBC backend selected."
#endif

#define FRAGSEAL_ENABLE_OPENSSL
