# Build the Android APK (arm64-v8a): the game with CMake into build-android, then the APK with Gradle
#
# Needs the dependencies from android\build-deps.ps1, the Vulkan SDK (dxc for the shaders) and a JDK 17+
# (the one of Android Studio is used if JAVA_HOME is not set).
#
# Output: android\app\build\outputs\apk\release\arx-vr.apk (or debug\arx-vr-debug.apk with -Debug)
#
# Usage: android\build.ps1 [-Debug] [-Reconfigure]

param([switch] $Debug, [switch] $Reconfigure)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Root 'build-android\arx'
$Sdk = if($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Ndk = Join-Path $Sdk 'ndk\27.1.12297006'
$Ninja = Join-Path $Sdk 'cmake\3.22.1\bin\ninja.exe'
$Toolchain = Join-Path $Ndk 'build\cmake\android.toolchain.cmake'

foreach($path in @($Ndk, $Ninja, $Toolchain, (Join-Path $Root 'libs\android-arm64\lib\libSDL2.so'))) {
	if(-not (Test-Path $path)) { throw "Not found: $path (see android\build-deps.ps1)" }
}

if(-not $env:JAVA_HOME) {
	$studioJdk = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
	if(Test-Path $studioJdk) { $env:JAVA_HOME = $studioJdk }
}
$env:ANDROID_HOME = $Sdk

# The game, always optimized: a debug build is too slow for VR
if($Reconfigure -or -not (Test-Path (Join-Path $Build 'CMakeCache.txt'))) {
	cmake -S $Root -B $Build -G Ninja -Wno-deprecated `
		"-DCMAKE_MAKE_PROGRAM=$Ninja" `
		"-DCMAKE_TOOLCHAIN_FILE=$Toolchain" `
		'-DANDROID_ABI=arm64-v8a' `
		'-DANDROID_PLATFORM=android-29' `
		'-DCMAKE_BUILD_TYPE=Release'
	if($LASTEXITCODE -ne 0) { throw 'CMake configuration failed' }
}
cmake --build $Build
if($LASTEXITCODE -ne 0) { throw 'Native build failed' }

# The APK
$task = if($Debug) { 'assembleDebug' } else { 'assembleRelease' }
Push-Location $PSScriptRoot
try {
	& .\gradlew.bat --console=plain $task
	if($LASTEXITCODE -ne 0) { throw 'Gradle build failed' }
} finally {
	Pop-Location
}

$type = if($Debug) { 'debug' } else { 'release' }
$name = if($Debug) { 'arx-vr-debug.apk' } else { 'arx-vr.apk' }
Write-Host "APK: $(Join-Path $PSScriptRoot "app\build\outputs\apk\$type\$name")"
