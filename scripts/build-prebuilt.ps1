[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$KotlinRoot = 'C:\kotlin',
    [Parameter(Mandatory)][string]$ClientJdk,
    [Parameter(Mandatory)][string[]]$ToolchainJdks,
    [string]$LlvmDir = 'C:/llvm-arm64-dev-full',
    [string]$LlvmMajor = '',
    # ARM64 JDK 21 the Gradle daemon runs on; it must be in the installations list or Gradle cannot find it
    [string]$DaemonJdk = 'C:\jdks\jdk21-arm64',
    # `powershell -File` does not parse "a, b, c" as one array; extra positional args are the remaining JDKs
    [Parameter(ValueFromRemainingArguments)][string[]]$MoreJdks = @()
)
$ErrorActionPreference = 'Stop'
$ToolchainJdks = @($ToolchainJdks + $MoreJdks) | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }

# run_konan.bat breaks when PATH contains ')' (e.g. Program Files (x86))
$env:PATH = (($env:PATH -split ';') | Where-Object { $_ -and $_ -notmatch '[()]' }) -join ';'
# the node-gradle plugin runs `uname` on Windows ARM64; Git for Windows provides it (appended so it shadows nothing)
$env:PATH += ';C:\Program Files\Git\usr\bin'
$env:JAVA_HOME = $ClientJdk

$lp = Join-Path $KotlinRoot 'local.properties'
if (-not (Test-Path $lp) -or -not (Select-String -Path $lp -Pattern '^kotlin\.native\.enabled=true' -Quiet)) {
    Add-Content -Path $lp -Value 'kotlin.native.enabled=true'
}

if (-not $LlvmMajor) {
    $LlvmMajor = (Get-ChildItem (Join-Path $LlvmDir 'lib\clang') -Directory | Select-Object -First 1).Name
}
if ($DaemonJdk -and (Test-Path "$DaemonJdk\bin\java.exe") -and ($ToolchainJdks -notcontains $DaemonJdk)) { $ToolchainJdks += $DaemonJdk }
$jdkPaths = ($ToolchainJdks | ForEach-Object { (Resolve-Path $_).Path }) -join ','

$common = @(
    "-Pkotlin.native.llvm=$LlvmDir",
    "-Pkotlin.native.llvm.next.mingw_arm64.version=$LlvmMajor",
    "-Dorg.gradle.java.installations.paths=$jdkPaths",
    '-Dorg.gradle.java.installations.auto-download=false',
    '--continue', '--console=plain'
)

"Gradle options: $($common -join ' ')"
Set-Location $KotlinRoot
& .\gradlew.bat ':kotlin-native:dist' ':kotlin-native:distPlatformLibs' @common
if ($LASTEXITCODE -ne 0) { throw "Build 1 failed ($LASTEXITCODE)" }

& .\gradlew.bat ':kotlin-native:bundlePrebuilt' '-x' ':kotlin-native:crossDist' '-x' ':kotlin-native:crossDistStdlibCache' '-x' ':kotlin-native:crossDistPlatformLibs' @common
if ($LASTEXITCODE -ne 0) { throw "Build 2 failed ($LASTEXITCODE)" }

$zip = Get-ChildItem (Join-Path $KotlinRoot 'kotlin-native') -Filter 'kotlin-native-prebuilt-windows-aarch64-*.zip' | Select-Object -First 1
"Done: $($zip.FullName)  ($([math]::Round($zip.Length/1MB,1)) MB)"
