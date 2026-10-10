# Packages an Arx Libertatis VR release: dist\ArxLibertatisVR-<version>-win64.zip
#
# Build first:  cmake --build build --config Release
# Then run:     pwsh -File package-vr.ps1   (or powershell -ExecutionPolicy Bypass -File package-vr.ps1)

param(
	[string] $BuildDir = "build",
	[string] $Config = "Release"
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$arx = Join-Path $root "arx"
$libs = Join-Path $root "libs"
$bin = Join-Path $root "$BuildDir\arx\$Config"

# The version is the last word of the first line of arx\VERSION ("Arx Libertatis VR 0.1.0")
$version = ((Get-Content (Join-Path $arx "VERSION") -TotalCount 1).Trim() -split " ")[-1]
$name = "ArxLibertatisVR-$version-win64"
$dist = Join-Path $root "dist"
$out = Join-Path $dist $name
$zip = Join-Path $dist "$name.zip"

if(-not (Test-Path (Join-Path $bin "arx.exe"))) {
	throw "$bin\arx.exe not found - build first: cmake --build $BuildDir --config $Config"
}

if(Test-Path $out) { Remove-Item -Recurse -Force $out }
if(Test-Path $zip) { Remove-Item -Force $zip }
New-Item -ItemType Directory -Force $out | Out-Null

function Copy-To([string] $source, [string] $destination) {
	$dir = Split-Path -Parent $destination
	if(-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
	Copy-Item -Recurse -Force $source $destination
}

# Programs and libraries (openxr_loader.dll is loaded at runtime, not imported)
foreach($file in "arx.exe", "arxsavetool.exe", "arxunpak.exe", "ArxIO.dll", "OpenAL32.dll", "SDL2.dll", "openxr_loader.dll") {
	Copy-To (Join-Path $bin $file) (Join-Path $out $file)
}

# Visual C++ runtime, so that the redistributable does not need to be installed
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -property installationPath
$crt = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -Directory |
	Sort-Object { [version]($_.Parent.Parent.Name) } | Select-Object -Last 1
if(-not $crt) { throw "Visual C++ runtime not found in $vs\VC\Redist\MSVC" }
foreach($file in "msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll") {
	Copy-To (Join-Path $crt.FullName $file) (Join-Path $out $file)
}

# Arx Libertatis data files (found in the "data" folder next to arx.exe) and the OpenAL HRTF
Get-ChildItem (Join-Path $arx "data\core") | ForEach-Object { Copy-To $_.FullName (Join-Path $out "data\$($_.Name)") }
Copy-To (Join-Path $libs "openal\share\openal") (Join-Path $out "data\openal")

# Documentation
Copy-To (Join-Path $arx "README-VR.md") (Join-Path $out "README-VR.txt")
Copy-To (Join-Path $arx "README.md") (Join-Path $out "README-ArxLibertatis.txt")
Copy-To (Join-Path $arx "VERSION") (Join-Path $out "VERSION.txt")
Copy-To (Join-Path $arx "AUTHORS") (Join-Path $out "AUTHORS.txt")
Copy-To (Join-Path $arx "COPYING") (Join-Path $out "COPYING.txt")
Copy-To (Join-Path $arx "LICENSE") (Join-Path $out "LICENSE.txt")

# Licenses
$licenses = [ordered]@{
	"arx-libertatis.LICENSE.DejaVu" = "$arx\LICENSE.DejaVu"
	"arx-libertatis.LICENSE.fast_float.txt" = "$arx\LICENSE.fast_float"
	"arx-libertatis.LICENSE.stb.txt" = "$arx\LICENSE.stb"
	"Boost.LICENSE_1_0.txt" = "$libs\boost\LICENSE_1_0.txt"
	"FreeType.LICENSE.txt" = "$libs\freetype\LICENSE"
	"FreeType.FTL.txt" = "$libs\freetype\FTL.TXT"
	"GLM.copying.txt" = "$libs\glm\copying.txt"
	"libepoxy.COPYING.txt" = "$libs\libepoxy\COPYING"
	"OpenAL_Soft.COPYING.txt" = "$libs\openal\COPYING"
	"OpenXR.LICENSE.txt" = "$libs\openxr\LICENSE.txt"
	"SDL2.COPYING.txt" = "$libs\sdl\COPYING.txt"
	"SDL2.README-SDL.txt" = "$libs\sdl\README-SDL.txt"
	"zlib.README.txt" = "$libs\zlib\README.txt"
}
foreach($entry in $licenses.GetEnumerator()) {
	Copy-To $entry.Value (Join-Path $out "license\$($entry.Key)")
}

Compress-Archive -Path $out -DestinationPath $zip
Write-Host "Created $zip"
