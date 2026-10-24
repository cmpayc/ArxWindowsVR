# Copy the Arx Fatalis data files from a PC installation to the headset, into /sdcard/ArxLibertatis
#
# Copies the .pak files and the loose override folders (graph, game, misc, sfx, speech, localisation) if present.
# The app needs "All files access" for this folder (asked on the first start), otherwise it uses its own folder:
# pass -AppFolder to copy there instead.
#
# Usage: android\push-data.ps1 -Source "C:\GOG Games\Arx Fatalis" [-AppFolder]

param(
	[Parameter(Mandatory = $true)] [string] $Source,
	[switch] $AppFolder
)

$ErrorActionPreference = 'Stop'

$Package = 'org.arxlibertatis.vr'
$Sdk = if($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Adb = Join-Path $Sdk 'platform-tools\adb.exe'
$Target = if($AppFolder) { "/sdcard/Android/data/$Package/files" } else { '/sdcard/ArxLibertatis' }

$paks = Get-ChildItem $Source -Filter '*.pak' -File
if(-not $paks) { throw "No .pak files in $Source" }

& $Adb shell mkdir -p $Target
if($LASTEXITCODE -ne 0) { throw 'No device connected?' }

foreach($pak in $paks) {
	Write-Host "Copying $($pak.Name)"
	# Lowercase names, like the game expects on Linux
	& $Adb push $pak.FullName "$Target/$($pak.Name.ToLowerInvariant())"
	if($LASTEXITCODE -ne 0) { throw "Could not copy $($pak.Name)" }
}

foreach($folder in 'graph', 'game', 'misc', 'sfx', 'speech', 'localisation') {
	$path = Join-Path $Source $folder
	if(Test-Path $path -PathType Container) {
		Write-Host "Copying $folder\"
		& $Adb push $path "$Target/"
		if($LASTEXITCODE -ne 0) { throw "Could not copy $folder" }
	}
}

Write-Host "Done: $Target"
