# Download and cross-compile the dependencies of the Android build (arm64-v8a) into libs/android-arm64
#
#  - SDL2 (shared, its Java sources go to android/app with sync-sdl-java, see the end)
#  - FreeType (static)
#  - OpenAL Soft (shared, AAudio / OpenSL ES backends)
#  - Khronos OpenXR loader for Android (prebuilt AAR from Maven Central)
#
# zlib and Vulkan come with the NDK, Boost and glm are header-only (libs/boost, libs/glm).
#
# Usage: android\build-deps.ps1 [-Clean]

param([switch] $Clean)

$ErrorActionPreference = 'Stop'

$SdlVersion = '2.30.9'
$FreetypeVersion = '2.13.3'
$OpenalVersion = '1.24.1'
$OpenxrVersion = '1.1.65'

$Root = Split-Path -Parent $PSScriptRoot
$Prefix = Join-Path $Root 'libs\android-arm64'
$Work = Join-Path $Root 'build-android\deps'
$Sdk = if($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Ndk = Join-Path $Sdk 'ndk\27.1.12297006'
$Ninja = Join-Path $Sdk 'cmake\3.22.1\bin\ninja.exe'
$Toolchain = Join-Path $Ndk 'build\cmake\android.toolchain.cmake'

foreach($path in @($Ndk, $Ninja, $Toolchain)) {
	if(-not (Test-Path $path)) { throw "Not found: $path (install the NDK 27.1 and CMake 3.22.1 with the Android SDK manager)" }
}

if($Clean -and (Test-Path $Work)) { Remove-Item -Recurse -Force $Work }
New-Item -ItemType Directory -Force $Work, $Prefix | Out-Null

function Get-Source([string] $Name, [string] $Url, [string] $Folder) {
	$archive = Join-Path $Work ([IO.Path]::GetFileName($Url))
	$source = Join-Path $Work $Folder
	if(-not (Test-Path $source)) {
		if(-not (Test-Path $archive)) {
			Write-Host "Downloading $Name"
			Invoke-WebRequest -Uri $Url -OutFile $archive
		}
		tar -xf $archive -C $Work
		if($LASTEXITCODE -ne 0) { throw "Could not extract $archive" }
	}
	return $source
}

function Build-CMake([string] $Name, [string] $Source, [string[]] $Options) {
	Write-Host "Building $Name"
	$build = Join-Path $Work "build-$Name"
	$arguments = @(
		'-S', $Source, '-B', $build, '-G', 'Ninja',
		"-DCMAKE_MAKE_PROGRAM=$Ninja",
		"-DCMAKE_TOOLCHAIN_FILE=$Toolchain",
		'-DANDROID_ABI=arm64-v8a',
		'-DANDROID_PLATFORM=android-29',
		'-DCMAKE_BUILD_TYPE=Release',
		"-DCMAKE_INSTALL_PREFIX=$Prefix",
		# Old projects declare an old minimum version
		'-DCMAKE_POLICY_VERSION_MINIMUM=3.5'
	) + $Options
	cmake @arguments
	if($LASTEXITCODE -ne 0) { throw "Configuring $Name failed" }
	cmake --build $build --target install
	if($LASTEXITCODE -ne 0) { throw "Building $Name failed" }
}

# SDL2
$sdl = Get-Source 'SDL2' "https://github.com/libsdl-org/SDL/releases/download/release-$SdlVersion/SDL2-$SdlVersion.tar.gz" "SDL2-$SdlVersion"
Build-CMake 'SDL2' $sdl @('-DSDL_SHARED=ON', '-DSDL_STATIC=OFF', '-DSDL_TEST=OFF')

# FreeType
$freetype = Get-Source 'FreeType' "https://download.savannah.gnu.org/releases/freetype/freetype-$FreetypeVersion.tar.xz" "freetype-$FreetypeVersion"
Build-CMake 'FreeType' $freetype @('-DBUILD_SHARED_LIBS=OFF', '-DFT_DISABLE_ZLIB=ON', '-DFT_DISABLE_BZIP2=ON',
                                   '-DFT_DISABLE_PNG=ON', '-DFT_DISABLE_HARFBUZZ=ON', '-DFT_DISABLE_BROTLI=ON')

# OpenAL Soft
$openal = Get-Source 'OpenAL Soft' "https://github.com/kcat/openal-soft/archive/refs/tags/$OpenalVersion.tar.gz" "openal-soft-$OpenalVersion"
Build-CMake 'openal' $openal @('-DLIBTYPE=SHARED', '-DALSOFT_UTILS=OFF', '-DALSOFT_EXAMPLES=OFF', '-DALSOFT_TESTS=OFF',
                               '-DALSOFT_INSTALL_CONFIG=OFF', '-DALSOFT_INSTALL_HRTF_DATA=OFF',
                               '-DALSOFT_INSTALL_AMBDEC_PRESETS=OFF', '-DALSOFT_INSTALL_EXAMPLES=OFF',
                               '-DALSOFT_INSTALL_UTILS=OFF')

# OpenXR loader: the official Android build from the Khronos group
$aar = Join-Path $Work "openxr_loader_for_android-$OpenxrVersion.aar"
if(-not (Test-Path $aar)) {
	Write-Host 'Downloading the OpenXR loader'
	Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/khronos/openxr/openxr_loader_for_android/$OpenxrVersion/openxr_loader_for_android-$OpenxrVersion.aar" -OutFile $aar
}
$openxr = Join-Path $Work "openxr-$OpenxrVersion"
if(Test-Path $openxr) { Remove-Item -Recurse -Force $openxr }
Expand-Archive -Path $aar -DestinationPath $openxr
New-Item -ItemType Directory -Force (Join-Path $Prefix 'lib'), (Join-Path $Prefix 'include') | Out-Null
Copy-Item (Join-Path $openxr 'jni\arm64-v8a\libopenxr_loader.so') (Join-Path $Prefix 'lib') -Force
Copy-Item (Join-Path $openxr 'prefab\modules\headers\include\openxr') (Join-Path $Prefix 'include') -Recurse -Force
Copy-Item (Join-Path $openxr 'META-INF\LICENSE') (Join-Path $Prefix 'LICENSE-OpenXR.txt') -Force

# The Java part of SDL must match the native library
$java = Join-Path $Root 'android\app\src\main\java\org\libsdl\app'
New-Item -ItemType Directory -Force $java | Out-Null
Copy-Item (Join-Path $sdl 'android-project\app\src\main\java\org\libsdl\app\*.java') $java -Force

Write-Host "Done: $Prefix"
