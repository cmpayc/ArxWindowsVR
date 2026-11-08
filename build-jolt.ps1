# Download and build Jolt Physics (static, x64, Release) into libs/jolt for the Windows build
#
# Arx links the release runtime (/MD) in all configurations (see arx/cmake/BuildType.cmake), so one Release build
# of Jolt serves both. The compile definitions that must match between Jolt and its users come with the installed
# CMake package (Jolt::Jolt), found by arx/CMakeLists.txt.
#
# Usage: .\build-jolt.ps1 [-Clean]

param([switch] $Clean)

$ErrorActionPreference = 'Stop'

$JoltVersion = '5.6.0'

$Root = $PSScriptRoot
$Prefix = Join-Path $Root 'libs\jolt'
$Work = Join-Path $Root 'build\deps'
$Source = Join-Path $Work "JoltPhysics-$JoltVersion"
$Build = Join-Path $Work 'build-jolt'

if($Clean) {
	foreach($path in @($Source, $Build, $Prefix)) {
		if(Test-Path $path) { Remove-Item -Recurse -Force $path }
	}
}
New-Item -ItemType Directory -Force $Work | Out-Null

if(-not (Test-Path $Source)) {
	$archive = Join-Path $Work "JoltPhysics-$JoltVersion.tar.gz"
	if(-not (Test-Path $archive)) {
		Write-Host "Downloading Jolt Physics $JoltVersion"
		Invoke-WebRequest -Uri "https://github.com/jrouwe/JoltPhysics/archive/refs/tags/v$JoltVersion.tar.gz" -OutFile $archive
	}
	tar -xf $archive -C $Work
	if($LASTEXITCODE -ne 0) { throw "Could not extract $archive" }
}

Write-Host "Building Jolt Physics $JoltVersion"
$arguments = @(
	'-S', (Join-Path $Source 'Build'), '-B', $Build,
	'-G', 'Visual Studio 17 2022', '-A', 'x64',
	"-DCMAKE_INSTALL_PREFIX=$Prefix",
	'-DTARGET_UNIT_TESTS=OFF',
	'-DTARGET_HELLO_WORLD=OFF',
	'-DTARGET_PERFORMANCE_TEST=OFF',
	'-DTARGET_SAMPLES=OFF',
	'-DTARGET_VIEWER=OFF',
	'-DENABLE_INSTALL=ON',
	'-DBUILD_SHARED_LIBS=OFF',
	# The runtime of arx
	'-DUSE_STATIC_MSVC_RUNTIME_LIBRARY=OFF',
	'-DINTERPROCEDURAL_OPTIMIZATION=OFF',
	# Arx builds without RTTI and exceptions is the Jolt default; keep the floating point environment of the game
	'-DFLOATING_POINT_EXCEPTIONS_ENABLED=OFF',
	'-DPROFILER_IN_DEBUG_AND_RELEASE=OFF',
	# The debug renderer define depends on the configuration of the user: off everywhere so that all match
	'-DDEBUG_RENDERER_IN_DEBUG_AND_RELEASE=OFF',
	'-DDEBUG_RENDERER_IN_DISTRIBUTION=OFF',
	# No GPU compute (hair simulation): it links Direct3D 12 and the Vulkan SDK of the build machine
	'-DJPH_USE_DX12=OFF', '-DJPH_USE_VK=OFF', '-DJPH_USE_MTL=OFF', '-DJPH_USE_CPU_COMPUTE=OFF',
	# Any x64 CPU with SSE4.2 (no AVX), like the rest of the game
	'-DUSE_AVX=OFF', '-DUSE_AVX2=OFF', '-DUSE_AVX512=OFF',
	'-DUSE_LZCNT=OFF', '-DUSE_TZCNT=OFF', '-DUSE_F16C=OFF', '-DUSE_FMADD=OFF'
)
cmake @arguments
if($LASTEXITCODE -ne 0) { throw 'Configuring Jolt failed' }
cmake --build $Build --config Release --target INSTALL
if($LASTEXITCODE -ne 0) { throw 'Building Jolt failed' }

Copy-Item (Join-Path $Source 'LICENSE') (Join-Path $Prefix 'LICENSE') -Force

Write-Host "Done: $Prefix"
