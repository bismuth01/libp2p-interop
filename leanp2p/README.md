# Setting up leanp2p

## Install vcpkg (one-time)

This project uses vcpkg in manifest mode via the CMake toolchain. You don’t need to "integrate" globally, but you must have vcpkg cloned and bootstrapped, and `VCPKG_ROOT` set.

1) Clone and bootstrap

```sh
git clone https://github.com/microsoft/vcpkg.git "$HOME/vcpkg"
"$HOME/vcpkg"/bootstrap-vcpkg.sh
```

2) Set VCPKG_ROOT (zsh)

Add to your shell profile so it’s available in every terminal:

```sh
echo 'export VCPKG_ROOT="$HOME/vcpkg"' >> ~/.zprofile
# if you use ~/.zshrc instead, write there and reload the shell
export VCPKG_ROOT="$HOME/vcpkg"
```

3) Verify

```sh
"$VCPKG_ROOT"/vcpkg version
```

## Building the project

This project is CMake + vcpkg manifest-based. The provided preset uses Ninja and the vcpkg toolchain.

First configure (will auto-install deps on first run):

```sh
cmake --preset default
```

Then build:

```sh
cmake --build build -j
```

Notes
- The preset builds Debug by default (see `CMakePresets.json`).
- To build Release without creating a new preset:
  ```sh
  cmake -S . -B build-release -G Ninja \
        -D CMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
        -D CMAKE_BUILD_TYPE=Release
  cmake --build build-release -j
  ```