plugins {
    id("common-configuration")
    id("com.autonomousapps.dependency-analysis")
    kotlin("multiplatform")
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
