param(
    [Parameter(Mandatory)][string]$LlvmBuilderDir,
    [string]$LlvmOutDir = 'C:\llvm-arm64-dev-full',
    [string]$LibffiOutDir = 'C:\libffi-arm64',
    [string]$Msys2Root = 'C:\msys64\clangarm64'
)
$ErrorActionPreference = 'Stop'

# Import the ARM64 Visual Studio environment (compiler for the extra tools)
$vcvars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsarm64.bat'
cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
}

$dist  = Join-Path $LlvmBuilderDir 'llvm-distribution'
$build = Join-Path $LlvmBuilderDir 'llvm-stage-2-build'
$src   = Join-Path $LlvmBuilderDir 'llvm-project'
foreach ($p in $dist, $build, $src) { if (-not (Test-Path $p)) { throw "Missing $p (run package.py with --save-temporary-files)" } }

$tools = 'opt llc llvm-link llvm-nm llvm-dis llvm-as llvm-objcopy llvm-strip llvm-readobj llvm-readelf llvm-ranlib ' +
         'llvm-profdata llvm-cov llvm-dwarfdump llvm-lib llvm-mc llvm-objdump llvm-size llvm-symbolizer llvm-config ' +
         'llvm-lto llvm-lto2 llvm-cxxfilt llvm-bcanalyzer llvm-extract llvm-strings llvm-install-name-tool llvm-dlltool dsymutil'
$targets = @($tools -split ' ') + 'llvm-libraries', 'llvm-mca', 'LLVMX86TargetMCA'
& ninja -C $build @targets
if ($LASTEXITCODE -ne 0) { throw 'ninja failed' }

New-Item -ItemType Directory -Force $LlvmOutDir | Out-Null
# trimmed distribution first (bin, lib\clang resource headers, libclang)
Copy-Item "$dist\*" $LlvmOutDir -Recurse -Force
# extra tools and DLLs
New-Item -ItemType Directory -Force "$LlvmOutDir\bin", "$LlvmOutDir\lib" | Out-Null
Copy-Item "$build\bin\*.exe", "$build\bin\*.dll" "$LlvmOutDir\bin" -Force
Copy-Item "$LlvmOutDir\bin\lld.exe" "$LlvmOutDir\bin\lld-link.exe" -Force
# static libraries
Copy-Item "$build\lib\*.lib" "$LlvmOutDir\lib" -Force
# headers: llvm, llvm-c, clang, clang-c (source + generated)
New-Item -ItemType Directory -Force "$LlvmOutDir\include" | Out-Null
foreach ($inc in "$src\llvm\include\*", "$build\include\*", "$src\clang\include\*", "$build\tools\clang\include\*") {
    Copy-Item $inc "$LlvmOutDir\include" -Recurse -Force
}

# compiler-rt builtins from MSYS2 into the clang resource dir
$major = (Get-ChildItem "$LlvmOutDir\lib\clang" -Directory | Select-Object -First 1).Name
$rtSrc = (Get-ChildItem "$Msys2Root\lib\clang\*\lib\windows\libclang_rt.builtins-aarch64.a" | Select-Object -First 1).FullName
New-Item -ItemType Directory -Force "$LlvmOutDir\lib\clang\$major\lib\windows" | Out-Null
Copy-Item $rtSrc "$LlvmOutDir\lib\clang\$major\lib\windows" -Force

# libffi: only ffi.h / ffitarget.h so MSYS2's include tree does not shadow MSVC headers
New-Item -ItemType Directory -Force "$LibffiOutDir\include", "$LibffiOutDir\lib" | Out-Null
Copy-Item "$Msys2Root\include\ffi.h", "$Msys2Root\include\ffitarget.h" "$LibffiOutDir\include" -Force
Copy-Item "$Msys2Root\lib\libffi.a" "$LibffiOutDir\lib\libffi.lib" -Force
Copy-Item $rtSrc "$LibffiOutDir\lib" -Force

# every exe/dll must be ARM64
$bad = Get-ChildItem "$LlvmOutDir\bin" -Include *.exe, *.dll -Recurse | Where-Object {
    $b = [IO.File]::ReadAllBytes($_.FullName)[0..1024]
    $off = [BitConverter]::ToInt32([byte[]]$b, 0x3C)
    [BitConverter]::ToUInt16([byte[]]$b, $off + 4) -ne 0xAA64
}
if ($bad) { throw "Non-ARM64 binaries: $($bad.Name -join ', ')" }
"OK. LLVM dir: $LlvmOutDir   libffi dir: $LibffiOutDir   LLVM major version: $major"
