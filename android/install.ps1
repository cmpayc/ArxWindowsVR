# Install the APK on the connected headset (USB or adb over Wi-Fi), start it and show its log
#
# Usage: android\install.ps1 [-Debug] [-NoLaunch] [-NoLog]

param([switch] $Debug, [switch] $NoLaunch, [switch] $NoLog)

$ErrorActionPreference = 'Stop'

$Package = 'org.arxlibertatis.vr'
$Sdk = if($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Adb = Join-Path $Sdk 'platform-tools\adb.exe'
$Apk = if($Debug) {
	Join-Path $PSScriptRoot 'app\build\outputs\apk\debug\arx-vr-debug.apk'
} else {
	Join-Path $PSScriptRoot 'app\build\outputs\apk\release\arx-vr.apk'
}

if(-not (Test-Path $Apk)) { throw "Not found: $Apk (run android\build.ps1 first)" }

& $Adb install -r $Apk
if($LASTEXITCODE -ne 0) { throw 'Install failed' }

if($NoLaunch) { return }

& $Adb shell am force-stop $Package
& $Adb logcat -c
& $Adb shell am start -n "$Package/.ArxActivity"
if($LASTEXITCODE -ne 0) { throw 'Launch failed' }

if($NoLog) { return }

# The game logs with the tag "arx", plus the OpenXR loader and runtime, SDL and crashes
& $Adb logcat -v time arx:V SDL:V SDL/APP:V OpenXR:V VrApi:I DEBUG:V AndroidRuntime:E libc:E '*:S'
