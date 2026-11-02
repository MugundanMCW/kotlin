# LLVM Build Infrastructure

[package.py](package.py) script automates downloading, building and packing of LLVM distribution used by Kotlin/Native.
### Requirements
* Check [LLVM requirements](https://llvm.org/docs/GettingStarted.html#requirements). Note that:
    * Visual Studio 2017 is required on Windows
    * Xcode is required on macOS
* [Python 3](https://www.python.org/)
* [ninja](https://ninja-build.org/)
* [git](https://git-scm.com/)
* [CMake](https://cmake.org/)

### Windows

Run this script from a Visual Studio Developer Command Prompt (e.g. "Developer Command Prompt
for VS", "x64 Native Tools Command Prompt for VS", or "ARM64 Native Tools Command Prompt for
VS") so that `cl.exe`/`link.exe` and the `INCLUDE`/`LIB` environment variables are already set
up. The script itself does not invoke `vsdevcmd.bat` or do any other environment setup on
Windows - it just runs `git`/`cmake`/`ninja` directly, the same way it does on Linux and macOS.

### Windows on ARM64

Running natively on Windows ARM64 (e.g. from an "ARM64 Native Tools Command Prompt for VS") is
**experimental and not verified by JetBrains**: no `windows-aarch64` LLVM distribution has ever
been produced or published, there is no existing bootstrap LLVM to download for that host (see
`--stage0` below), and the rest of the Kotlin/Native build (`konan.properties`,
`gradle.properties`) has no entries for a `mingw_arm64` host yet. Treat a Windows ARM64 run of
this script as a first attempt, not a supported path.

### Usage

Just run
```
python3 package.py
```
It will create a `llvm-distribution` folder which contains LLVM distribution.  
Note that build will take a lot of time and all your machine cores. 😈  
See [HACKING.md](../../HACKING.md#using-different-llvm-distributions-as-part-of-kotlinnative-compilation-pipeline) 
on how to use freshly built distribution.

### Building distribution for end-users
By default, `package.py` installs a lot of LLVM components that is not really required to use Kotlin/Native compiler.
To build only essential parts, run the following command:

```
python3 package.py --build-targets install-distribution --distribution-components $DISTRIBUTION_COMPONENTS
```
Set of required `$DISTRIBUTION_COMPONENTS` depends on OS:

| OS      | Distribution components                                                                |
|---------|----------------------------------------------------------------------------------------|
| Windows | `clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers`             |
| macOS   | `clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers`             |
| Linux   | `clang libclang lld llvm-cov llvm-profdata llvm-ar clang-resource-headers compiler-rt` |

### Tuning
Run `python3 package.py -h` to check how one can tune script's behavior.
Some examples:
* `--pack` creates an archive (`zip` on Windows, `tar.gz` on macOS and Linux) with distribution
  alongside with its SHA256.
* `--install-path` allows overriding distribution's output directory.
* `--num-stages` specifies number of steps in build. Passing 2 or more makes bootstrap build which
  means that LLVM will build itself by using distribution from the previous step.
* `--stage0` allows using existing LLVM toolchain for bootstrapping.
* `--lto thin` or `--lto full` enables LTO when building the final LLVM stage.
  Earlier stages keep their original configuration. Omitting this option leaves
  the LTO configuration unchanged.
* `--build-targets` specifies what targets will be passed to Ninja.
* `--distribution-components` is a list of components that will be installed with `install-distribution` build target.

### Docker

#### Linux 

You can use Docker to build LLVM for Linux:
```shell
docker build -t kotlin-llvm-builder --file images/linux/Dockerfile .
docker run --rm -it -v <HOST_PATH>:/output kotlin-llvm-builder --install-path /output/llvm-<version>-x86_64-linux --pack
```

#### Windows 

> [!WARNING]  
> Windows containers support is experimental

If your host machine is Windows, you can use Windows Docker container to build LLVM for Windows: 
```shell 
docker build -t kotlin-llvm-builder --file images/windows/Dockerfile .
docker run --rm -it -v <HOST_PATH>:/output kotlin-llvm-builder --instal-path /output/llvm-<version>-x86_64-windows --pack
```

### Known problems
1. No way to run LLVM tests out of the box.
