/**
 * Used in for modules in 'native/objcexport-heade-generator/testDependencies.
 * Such libraries can build klibs that can then later be used for running objc export tests against
 */
plugins {
    kotlin("multiplatform")
}

/*
Depends on https://youtrack.jetbrains.com/issue/KT-65985
 */
providers.systemProperty("kotlin.internal.native.test.nativeHome").orNull?.let { nativeHome ->
    extensions.extraProperties.set("kotlin.native.home", nativeHome)
}

// No published kotlin-native-prebuilt exists for Windows on ARM64 (KT-82419), so registering native targets would fail resolution.
val isWindowsArm64Host = System.getProperty("os.name").startsWith("Windows") &&
        System.getProperty("os.arch").lowercase() in setOf("aarch64", "arm64")

kotlin {
    if (!isWindowsArm64Host) {
        macosArm64()
        @Suppress("DEPRECATION_ERROR", "DEPRECATION")
        macosX64()
        linuxX64()
        linuxArm64()
        mingwX64()
    }
}
