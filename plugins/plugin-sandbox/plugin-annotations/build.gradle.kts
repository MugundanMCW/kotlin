@file:OptIn(org.jetbrains.kotlin.gradle.ExperimentalWasmDsl::class)

import org.gradle.kotlin.dsl.support.serviceOf
import org.jetbrains.kotlin.konan.target.HostManager

plugins {
    id("common-configuration")
    id("com.autonomousapps.dependency-analysis")
    kotlin("multiplatform")
    id("binaryen-configuration")
}

val buildFeatures = serviceOf<BuildFeatures>()
kotlin {
    jvm()
    js {
        if (!buildFeatures.isolatedProjects.active.get()) {
            binaries.executable()
        }
    }
    wasmJs {
        if (!buildFeatures.isolatedProjects.active.get()) {
            binaries.executable()
        }
    }

    if (kotlinBuildProperties.isInIdeaSync.get()) {
        // this magic is needed because of explicit dependency of common
        // source set on the stdlib
        val hostOs = System.getProperty("os.name")
        val isMingwX64 = hostOs.startsWith("Windows")

        @Suppress("DEPRECATION", "DEPRECATION_ERROR")
        when {
            hostOs == "Mac OS X" -> macosX64("native")
            hostOs == "Linux" -> linuxX64("native")
            isMingwX64 -> mingwX64("native")
            else -> throw GradleException("Host OS is not supported in Kotlin/Native.")
        }
    } else if (HostManager.hostIsSupported && HostManager.host.name != "mingw_arm64") { // no published kotlin-native-prebuilt for mingw_arm64 (KT-82419)
        linuxX64()
        macosArm64()
        mingwX64()
    } else {
        // Host is not recognized by Kotlin/Native (e.g. Windows on ARM64, KT-82419-style hosts).
        // Registering any native target here would force resolution of a Kotlin/Native bootstrap
        // compiler for this host's classifier, which JetBrains has never published, breaking even
        // pure-JVM/JS/Wasm builds. Skip native klib targets entirely on such hosts.
        logger.warn(
            "Skipping Kotlin/Native targets for :plugin-annotations: " +
                    "host '${HostManager.hostOs()}-${HostManager.hostArchOrNull()}' has no published Kotlin/Native bootstrap compiler."
        )
    }

    sourceSets {
        val commonMain = getByName("commonMain") {
            dependencies {
                implementation(kotlinStdlib())
            }
        }
    }
}

sourceSets {
    "main" { projectDefault() }
    "test" { none() }
}

tasks.register("distAnnotations") {
    dependsOn("jvmJar", "jsJar", "wasmJsJar")
}
