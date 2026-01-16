set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

BaseFile := os()

# Global environment variables
export https_proxy := "http://127.0.0.1:7897"
export http_proxy := "http://127.0.0.1:7897"
export all_proxy := "http://127.0.0.1:7897"

# --- Platform-specific Path Logic (Compatible with Linux, macOS, Windows) ---

ProjectRoot := justfile_directory()
Arch := arch()

# 1. FFmpeg Directory Name
FFmpegDirName := if os() == "windows" {
    "ffmpeg-8.0-windows-desktop-clang-gpl-lite"
} else if os() == "macos" {
    if Arch == "aarch64" { "ffmpeg-arm64" } else { "ffmpeg-x86_64" }
} else {
    "ffmpeg-8.0-linux-clang-gpl-lite"
}

# 2. FFmpeg Lib Subdirectory (Windows dlls in bin, macOS/Linux in lib)
FFmpegLibSub := if os() == "windows" {
    "bin"
} else if os() == "macos" {
    "lib"
} else {
    if Arch == "aarch64" { "lib/arm64" } else { "lib/amd64" }
}

# 3. Qt Version and Arch Directory
QtVer := if os() == "windows" { "6.7.3" } else if Arch == "aarch64" { "6.7.3" } else { "6.4.3" }
QtArchDir := if os() == "windows" {
    "msvc2019_64"
} else if os() == "macos" {
    "macos"
} else {
    if Arch == "aarch64" { "gcc_arm64" } else { "gcc_64" }
}
# Qt dlls in bin on Windows, so in lib on macOS/Linux
QtLibSub := if os() == "windows" { "bin" } else { "lib" }

# Assemble Full Paths
LibPathFFmpeg := ProjectRoot / "ext" / FFmpegDirName / FFmpegLibSub
LibPathQt := ProjectRoot / "ext" / QtVer / QtArchDir / QtLibSub

# 4. Set Environment Variables based on Platform
# Linux:   LD_LIBRARY_PATH
# macOS:   DYLD_FALLBACK_LIBRARY_PATH
# Windows: PATH

export LD_LIBRARY_PATH := if os() == "linux" {
    LibPathFFmpeg + ":" + LibPathQt + ":" + env_var_or_default("LD_LIBRARY_PATH", "")
} else {
    env_var_or_default("LD_LIBRARY_PATH", "")
}

export DYLD_FALLBACK_LIBRARY_PATH := if os() == "macos" {
    LibPathFFmpeg + ":" + LibPathQt + ":" + env_var_or_default("DYLD_FALLBACK_LIBRARY_PATH", "")
} else {
    env_var_or_default("DYLD_FALLBACK_LIBRARY_PATH", "")
}

export PATH := if os() == "windows" {
    LibPathFFmpeg + ";" + LibPathQt + ";" + env_var_or_default("PATH", "")
} else {
    env_var_or_default("PATH", "")
}

# --- Recipes ---

run *param:
    just -f _scripts/{{BaseFile}}.just run {{param}}

test *param:
    just -f _scripts/{{BaseFile}}.just test {{param}}

build *param:
    just -f _scripts/{{BaseFile}}.just build {{param}}

build-debug *param:
    just -f _scripts/{{BaseFile}}.just build-debug {{param}}

debug *param:
    just -f _scripts/{{BaseFile}}.just debug {{param}}

profile *param:
    just -f _scripts/{{BaseFile}}.just profile {{param}}

clippy *param:
    just -f _scripts/{{BaseFile}}.just clippy {{param}}

install-deps *param:
    just -f _scripts/{{BaseFile}}.just install-deps {{param}}

deploy *param:
    just -f _scripts/{{BaseFile}}.just deploy {{param}}

bundle *param:
    just -f _scripts/{{BaseFile}}.just bundle {{param}}

android *param:
    just -f _scripts/android.just {{param}}

ios *param:
    just -f _scripts/ios.just {{param}}

publish version:
    #!/bin/bash
    git clone --depth 1 git@github.com:gyroflow/gyroflow.git __publish
    pushd __publish
    sed -i'' -E "0,/ProjectVersion := \"[0-9\.a-z-]+\""/s//ProjectVersion := \"{{version}}\"" _scripts/common.just
    sed -i'' -E "0,/version = \"[0-9\.a-z-]+\""/s//version = \"{{version}}\"" Cargo.toml
    sed -i'' -E "0,/version = \"[0-9\.a-z-]+\""/s//version = \"{{version}}\"" src/core/Cargo.toml
    sed -i'' -E "/<key>CFBundleShortVersionString<.key>/ s/<string>[0-9\.a-z-]+<.string>/<string>{{version}}<\/string>/" _deployment/mac/Gyroflow.app/Contents/Info.plist
    sed -i'' -E "/<key>CFBundleVersion<.key>/ s/<string>[0-9\.a-z-]+<.string>/<string>{{version}}<\/string>/" _deployment/mac/Gyroflow.app/Contents/Info.plist
    sed -i'' -E "0,/Gyroflow v[0-9\.a-z-]+/s//Gyroflow v{{version}}/" src/cli.rs
    sed -i'' -E "0,/versionName=\"[0-9\.a-z-]+\""/s//versionName=\"{{version}}\"" _deployment/android/AndroidManifest.xml
    sed -i'' -E "/<key>CFBundleShortVersionString<.key>/ s/<string>[0-9\.a-z-]+<.string>/<string>{{version}}<\/string>/" _deployment/ios/Info.plist
    sed -i'' -E "/<key>CFBundleVersion<.key>/ s/<string>[0-9\.a-z-]+<.string>/<string>{{version}}<\/string>/" _deployment/ios/Info.plist
    sed -i'' -E "0,/Identity Version=\"[0-9\.a-z-]+\""/s//Identity Version=\"{{version}}.0\"" _deployment/windows/AppxManifest.xml
    pushd src/core
        cargo update
    popd
    cargo update
    git commit -a -m "Release v{{version}}"
    git tag -a "v{{version}}" -m "Release v{{version}}"
    git push origin
    git push origin "v{{version}}"
    popd
    rm -rf __publish
    git pull