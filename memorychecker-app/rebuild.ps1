<#
  rebuild.ps1
  memorychecker.html을 수정한 뒤 이 스크립트를 실행하면
  Capacitor 웹 자산 동기화 + Gradle APK 빌드까지 한 번에 처리한다.

  사용법 (PowerShell):
    cd C:\Users\chris\PycharmProjects\PythonProject\memorychecker-app
    .\rebuild.ps1            # 디버그 APK (테스트용, 서명 자동)
    .\rebuild.ps1 -Release   # 릴리즈 APK (release.keystore로 서명, 배포용)

  결과물:
    android\app\build\outputs\apk\debug\app-debug.apk
    android\app\build\outputs\apk\release\app-release.apk   (-Release 사용 시)
#>

param(
    [switch]$Release
)

$ErrorActionPreference = "Stop"

$toolsBase = "C:\Users\chris\android-build-tools"
$projRoot  = "C:\Users\chris\PycharmProjects\PythonProject\memorychecker-app"
$sourceHtml = "C:\Users\chris\PycharmProjects\PythonProject\memorychecker.html"
$destHtml   = "$projRoot\www\index.html"

if ($Release -and -not (Test-Path "$projRoot\android\keystore.properties")) {
    throw "keystore.properties가 없습니다 ($projRoot\android\keystore.properties). 릴리즈 서명 설정이 되어 있지 않습니다."
}

# 이 세션의 PowerShell 프로세스는 User 환경변수를 자동으로 새로 읽지 않으므로 매번 명시적으로 지정한다.
$env:JAVA_HOME        = "$toolsBase\jdk21"
$env:ANDROID_HOME     = "$toolsBase\android-sdk"
$env:ANDROID_SDK_ROOT = "$toolsBase\android-sdk"
$env:Path = "$toolsBase\node;$toolsBase\jdk21\bin;$toolsBase\android-sdk\platform-tools;$toolsBase\android-sdk\cmdline-tools\latest\bin;$env:Path"

Write-Host "==> 1/3 memorychecker.html -> www/index.html 복사" -ForegroundColor Cyan
Copy-Item $sourceHtml $destHtml -Force

Set-Location $projRoot

Write-Host "==> 2/3 Capacitor 웹 자산 동기화 (npx cap sync android)" -ForegroundColor Cyan
npx cap sync android
if ($LASTEXITCODE -ne 0) { throw "cap sync 실패 (exit $LASTEXITCODE)" }

if ($Release) {
    $gradleTask = "assembleRelease"
    $apk = "$projRoot\android\app\build\outputs\apk\release\app-release.apk"
    $label = "릴리즈(서명)"
} else {
    $gradleTask = "assembleDebug"
    $apk = "$projRoot\android\app\build\outputs\apk\debug\app-debug.apk"
    $label = "디버그"
}

Write-Host "==> 3/3 Gradle $label APK 빌드 ($gradleTask)" -ForegroundColor Cyan
Set-Location "$projRoot\android"
.\gradlew.bat $gradleTask --no-daemon
if ($LASTEXITCODE -ne 0) { throw "gradlew $gradleTask 실패 (exit $LASTEXITCODE)" }

if (Test-Path $apk) {
    $item = Get-Item $apk
    Write-Host ""
    Write-Host "빌드 완료 ($label): $apk" -ForegroundColor Green
    Write-Host ("크기: {0} MB, 시각: {1}" -f [math]::Round($item.Length/1MB,2), $item.LastWriteTime)
} else {
    Write-Warning "빌드는 성공했다는데 APK 파일을 찾지 못했습니다: $apk"
}
