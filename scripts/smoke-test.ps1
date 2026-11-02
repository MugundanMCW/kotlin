param(
    [Parameter(Mandatory)][string]$Zip,
    [Parameter(Mandatory)][string]$Jdk,
    [string]$LlvmDir = 'C:/llvm-arm64-dev-full',
    [string]$LlvmMajor = '21'
)
$ErrorActionPreference = 'Stop'

$work = Join-Path $env:TEMP ("kn-arm64-smoke-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $work | Out-Null
Expand-Archive $Zip (Join-Path $work 'kn')
$kn = (Get-ChildItem (Join-Path $work 'kn') -Directory | Select-Object -First 1).FullName
$java = Join-Path $Jdk 'bin\java.exe'
$env:PATH = "$($LlvmDir -replace '/','\')\bin;C:\msys64\clangarm64\bin;" + (($env:PATH -split ';' | Where-Object { $_ -notmatch '[()]' }) -join ';')

function Get-PeMachine($exe) {
    $b = [IO.File]::ReadAllBytes($exe)
    $off = [BitConverter]::ToInt32($b, 0x3C)
    $m = [BitConverter]::ToUInt16($b, $off + 4)
    switch ($m) { 0xAA64 { 'aa64' } 0x8664 { 'x64' } default { '{0:x}' -f $m } }
}

$samples = @{
    hello    = 'fun main() { println("Hello from Kotlin/Native on Windows ARM64!"); println("1 + 2 = ${1 + 2}") }'
    platform = @'
import kotlinx.cinterop.*
import platform.posix.*
import platform.windows.*
fun main() {
    println("pid > 0: ${GetCurrentProcessId() > 0u}")
    println("time() > 0: ${time(null) > 0}")
    println("tick64 > 0: ${GetTickCount64() > 0uL}")
    println("strlen(\"arm64\") = ${strlen("arm64")}")
}
'@
}
foreach ($name in 'hello', 'platform') {
    "== $name =="
    $src = Join-Path $work "$name.kt"
    Set-Content $src $samples[$name]
    $exe = Join-Path $work "$name.exe"
    & $java -ea -Xmx3G "-Dkonan.home=$kn" -cp "$kn\konan\lib\kotlin-native-compiler-embeddable.jar" `
        org.jetbrains.kotlin.cli.utilities.MainKt konanc $src -o (Join-Path $work $name) -target mingw_arm64 `
        "-Xoverride-konan-properties=llvm.mingw_arm64.dev=$LlvmDir;llvmVersion.mingw_arm64=$LlvmMajor"
    if ($LASTEXITCODE -ne 0) { throw "Compilation of $name failed" }
    $mt = Get-PeMachine $exe
    "machine type: $mt (aa64 = ARM64)"
    if ($mt -ne 'aa64') { throw "$name.exe is not ARM64" }
    & $exe
    if ($LASTEXITCODE -ne 0) { throw "$name.exe failed" }
}
"Smoke test passed. Work dir: $work"
