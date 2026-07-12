$ErrorActionPreference = "Stop"

Write-Host "=> 1. Checking Workspace & Java..."
New-Item -ItemType Directory -Force -Path shizuku_libs | Out-Null

if (Get-Command javac -ErrorAction SilentlyContinue) {
    Write-Host "   [System] Java found in PATH."
} else {
    Write-Host "   [Local] Java not found. Fetching OpenJDK 17..."
    New-Item -ItemType Directory -Force -Path build_tools\jdk_temp | Out-Null
    $htmlJdk = Invoke-RestMethod "[https://jdk.java.net/archive/](https://jdk.java.net/archive/)"
    $jdkUrl = [regex]::Match($htmlJdk, 'https://download\.java\.net/java/GA/jdk17[^"]+windows-x64_bin\.zip').Value
    Invoke-WebRequest -Uri $jdkUrl -OutFile "build_tools\jdk.zip"
    Expand-Archive -Path "build_tools\jdk.zip" -DestinationPath "build_tools\jdk_temp" -Force
    $jdkFolder = Get-ChildItem -Path "build_tools\jdk_temp" -Directory | Select-Object -First 1
    Move-Item -Path "$($jdkFolder.FullName)" -Destination "build_tools\jdk" -Force
    $env:PATH = "$PWD\build_tools\jdk\bin;" + $env:PATH
}

Write-Host "=> 2. Checking Android SDK..."
if ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\platforms\android-35\android.jar")) {
    Write-Host "   [System] Android SDK 35 found at $env:ANDROID_HOME."
    $AndroidJar = "$env:ANDROID_HOME\platforms\android-35\android.jar"
    $D8Cmd = "$env:ANDROID_HOME\build-tools\35.0.0\d8.bat"
    $AaptCmd = "$env:ANDROID_HOME\build-tools\35.0.0\aapt.exe"
    $ApkSignerCmd = "$env:ANDROID_HOME\build-tools\35.0.0\apksigner.bat"
} else {
    Write-Host "   [Local] Android SDK 35 missing. Fetching dynamically..."
    New-Item -ItemType Directory -Force -Path build_tools\sdk | Out-Null
    $htmlSdk = Invoke-RestMethod "[https://developer.android.com/studio](https://developer.android.com/studio)"
    $sdkUrl = [regex]::Match($htmlSdk, 'https://dl\.google\.com/android/repository/commandlinetools-win-[0-9]*_latest\.zip').Value
    Invoke-WebRequest -Uri $sdkUrl -OutFile "build_tools\cmdline.zip"
    Expand-Archive -Path "build_tools\cmdline.zip" -DestinationPath "build_tools\sdk" -Force
    New-Item -ItemType Directory -Force -Path "build_tools\sdk\cmdline-tools\latest" | Out-Null
    Move-Item -Path "build_tools\sdk\cmdline-tools\bin", "build_tools\sdk\cmdline-tools\lib", "build_tools\sdk\cmdline-tools\source.properties" -Destination "build_tools\sdk\cmdline-tools\latest" -Force
    echo y | .\build_tools\sdk\cmdline-tools\latest\bin\sdkmanager.bat --licenses > $null
    .\build_tools\sdk\cmdline-tools\latest\bin\sdkmanager.bat "platforms;android-35" "build-tools;35.0.0" > $null$AndroidJar = "build_tools\sdk\platforms\android-35\android.jar"
    $D8Cmd = "build_tools\sdk\build-tools\35.0.0\d8.bat"
    $AaptCmd = "build_tools\sdk\build-tools\35.0.0\aapt.exe"
    $ApkSignerCmd = "build_tools\sdk\build-tools\35.0.0\apksigner.bat"
}

Write-Host "=> 3. Checking Shizuku Libs..."
if (!(Test-Path "shizuku_libs\shizuku-api.jar")) {
    $libs = @("api", "provider", "shared", "aidl")
    foreach ($lib in$libs) {
        Invoke-WebRequest -Uri "[https://repo1.maven.org/maven2/dev/rikka/shizuku/$lib/13.1.5/$lib-13.1.5.aar](https://repo1.maven.org/maven2/dev/rikka/shizuku/$lib/13.1.5/$lib-13.1.5.aar)" -OutFile "shizuku_libs\$lib.zip"
        Expand-Archive -Path "shizuku_libs\$lib.zip" -DestinationPath "shizuku_libs\$lib" -Force
        Move-Item -Path "shizuku_libs\$lib\classes.jar" -Destination "shizuku_libs\shizuku-$lib.jar" -Force
        Remove-Item -Recurse -Force "shizuku_libs\$lib", "shizuku_libs\$lib.zip"
    }
} else {
    Write-Host "   [System] Shizuku libs already present."
}

Write-Host "=> 4. Compiling and Signing..."
Remove-Item -Force -ErrorAction SilentlyContinue classes.dex, unsigned.apk, ShizukuAudioRouter.apk

javac -cp "$AndroidJar;shizuku_libs\shizuku-api.jar;shizuku_libs\shizuku-provider.jar;shizuku_libs\shizuku-shared.jar;shizuku_libs\shizuku-aidl.jar" -source 1.8 -target 1.8 -d . src\com\custom\audiorouter\*.java

& $D8Cmd --lib$AndroidJar --output . com\custom\audiorouter\*.class shizuku_libs\shizuku-aidl.jar shizuku_libs\shizuku-api.jar shizuku_libs\shizuku-provider.jar shizuku_libs\shizuku-shared.jar

& $AaptCmd package -f -M AndroidManifest.xml -S res -I$AndroidJar -F unsigned.apk --min-sdk-version 26 --target-sdk-version 35

jar uf unsigned.apk classes.dex

if (!(Test-Path dummy.keystore)) {
    keytool -genkey -v -keystore dummy.keystore -alias dummy -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US" | Out-Null
}

& $ApkSignerCmd sign --ks dummy.keystore --ks-pass pass:android unsigned.apk

Rename-Item -Path "unsigned.apk" -NewName "ShizukuAudioRouter.apk" -Force
Remove-Item -Recurse -Force com, classes.dex, build_tools\jdk_temp, build_tools\jdk.zip, build_tools\cmdline.zip -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==========================================================="
Write-Host "✅ SUCCESS! Your file is ready: ShizukuAudioRouter.apk"
Write-Host "==========================================================="
