/*
 * Copyright 2010-2026 JetBrains s.r.o. and Kotlin Programming Language contributors.
 * Use of this source code is governed by the Apache 2.0 license that can be found in the license/LICENSE.txt file.
 */

// KT-82419: on Windows ARM64 the callbacks library is linked against a static libffi built with MSYS2 CLANGARM64,
// whose objects were compiled with stack protection. Provide the symbols the MSVC-ABI link otherwise lacks.
#if defined(_WIN32) && defined(__aarch64__)
#include <stdint.h>
#include <stdlib.h>

uintptr_t __stack_chk_guard = (uintptr_t)0x595e9fbd94fda766ULL;

__declspec(noreturn) void __stack_chk_fail(void) {
    abort();
}
#endif
