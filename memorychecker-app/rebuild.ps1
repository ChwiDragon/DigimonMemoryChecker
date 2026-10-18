<#
  rebuild.ps1 - bump the version, then build the signed APK and the Google Play bundle (.aab).

  Usage (from memorychecker-app):
    powershell -ExecutionPolicy Bypass -File rebuild.ps1                  # 1.1.0 -> 1.1.1, versionCode +1
    powershell -ExecutionPolicy Bypass -File rebuild.ps1 -Version 1.2.0   # set versionName, versionCode +1
    powershell -ExecutionPolicy Bypass -File rebuild.ps1 -NoBump          # rebuild the current version

  Every build bumps the version (Play rejects a versionCode it has already seen):
    android/app/build.gradle   versionCode +1, versionName
    memorycheckerapk.html      APP.version / APP.build (shown at the bottom of HELP)
    memorychecker.html         regenerated from memorycheckerapk.html by tools\make_browser.py

  Outputs:
    memorychecker.apk                                  signed APK (GitHub / direct install)
    release/memorychecker-<ver>-vc<code>.apk / .aab    versioned copies; upload the .aab to Play Console
    release/memorychecker-<ver>-vc<code>-mapping.txt   R8 deobfuscation file (also embedded in the .aab)

  memorycheckerapk.html is the app source; memorychecker.html is generated from it (never edit it by hand).
#>
param(
    [string]$Version,
    [switch]$NoBump
)

$ErrorActionPreference = 'Stop'
$tools = 'C:\Users\chris\android-build-tools'
$env:JAVA_HOME = "$tools\jdk21"
$env:ANDROID_HOME = "$tools\android-sdk"
$env:ANDROID_SDK_ROOT = "$tools\android-sdk"
$env:Path = "$tools\node;$env:JAVA_HOME\bin;$tools\android-sdk\platform-tools;$env:Path"

$app = $PSScriptRoot
$gradleFile = "$app\android\app\build.gradle"
$htmlFiles = @("$app\memorycheckerapk.html")
$utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path "$app\android\keystore.properties")) {
    throw "android\keystore.properties is missing - release signing is not set up (see release\signing-backup)."
}

# 1. version bump
$gradle = [IO.File]::ReadAllText($gradleFile)
$code = [int][regex]::Match($gradle, 'versionCode (\d+)').Groups[1].Value
$name = [regex]::Match($gradle, 'versionName "([^"]+)"').Groups[1].Value
if (-not $NoBump) {
    $code++
    if ($Version) {
        $name = $Version
    } else {
        $parts = [System.Collections.ArrayList]@($name.Split('.') | ForEach-Object { [int]$_ })
        while ($parts.Count -lt 3) { [void]$parts.Add(0) }
        $parts[$parts.Count - 1]++
        $name = $parts -join '.'
    }
    $gradle = $gradle -replace 'versionCode \d+', "versionCode $code"
    $gradle = $gradle -replace 'versionName "[^"]+"', "versionName `"$name`""
    [IO.File]::WriteAllText($gradleFile, $gradle, $utf8)
}
$today = Get-Date -Format 'yyyy-MM-dd'
foreach ($f in $htmlFiles) {
    $html = [IO.File]::ReadAllText($f)
    $new = $html -replace 'version: "[^"]*", build: "[^"]*"', "version: `"$name`", build: `"$today`""
    if ($new -eq $html -and $html -notmatch "version: `"$name`"") { throw "APP version line not found in $f" }
    [IO.File]::WriteAllText($f, $new, $utf8)
}
Write-Host "==> version $name (versionCode $code)" -ForegroundColor Cyan
# browser / PWA / artifact version follows the app source
$python = "$app\..\.venv\Scripts\python.exe"
if (-not (Test-Path $python)) { $python = 'python' }
& $python "$app\tools\make_browser.py"
if ($LASTEXITCODE -ne 0) { throw "make_browser.py failed (exit $LASTEXITCODE)" }

# 2. web files -> www -> android
New-Item -ItemType Directory -Force "$app\www" | Out-Null
Copy-Item "$app\memorycheckerapk.html" "$app\www\index.html" -Force
Set-Location $app
cmd /c "npx cap sync android"
if ($LASTEXITCODE -ne 0) { throw "cap sync failed (exit $LASTEXITCODE)" }

# 3. signed APK + bundle
Set-Location "$app\android"
cmd /c ".\gradlew.bat assembleRelease bundleRelease --console=plain --no-daemon"
if ($LASTEXITCODE -ne 0) { throw "gradle build failed (exit $LASTEXITCODE)" }

# 4. copies
$release = "$app\release"
New-Item -ItemType Directory -Force $release | Out-Null
$apk = "$app\android\app\build\outputs\apk\release\app-release.apk"
$aab = "$app\android\app\build\outputs\bundle\release\app-release.aab"
Copy-Item $apk "$app\memorychecker.apk" -Force
Copy-Item $apk "$release\memorychecker-$name-vc$code.apk" -Force
Copy-Item $aab "$release\memorychecker-$name-vc$code.aab" -Force
# R8 deobfuscation file: already inside the .aab (Play reads it automatically); this copy is
# for uploading by hand (App bundle explorer > Downloads > ReTrace mapping file) if ever needed.
$mapping = "$app\android\app\build\outputs\mapping\release\mapping.txt"
if (Test-Path $mapping) { Copy-Item $mapping "$release\memorychecker-$name-vc$code-mapping.txt" -Force }
Set-Location $app
Write-Host ""
Write-Host "built $name (vc$code):" -ForegroundColor Green
Write-Host "  memorychecker.apk"
Write-Host "  release\memorychecker-$name-vc$code.apk"
Write-Host "  release\memorychecker-$name-vc$code.aab   <- upload this to Play Console"
Write-Host "  release\memorychecker-$name-vc$code-mapping.txt   (deobfuscation file, also inside the .aab)"
