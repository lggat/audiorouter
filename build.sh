#!/bin/bash
set -e
#
echo "=> 1. Checking Workspace & Java..."
mkdir -p shizuku_libs

if command -v javac >/dev/null 2>&1; then
    echo "   [System] Java found in PATH."
else
    echo "   [Local] Java not found. Fetching OpenJDK 17..."
    mkdir -p build_tools/jdk
    OS_TYPE=$(uname -s)
    ARCH=$(uname -m)
    if [ "$OS_TYPE" = "Darwin" ]; then
        [ "$ARCH" = "arm64" ] && JDK_PATTERN="macos-aarch64_bin.tar.gz" || JDK_PATTERN="macos-x64_bin.tar.gz"
    else
        JDK_PATTERN="linux-x64_bin.tar.gz"
    fi
    JDK_URL=$(curl -s [https://jdk.java.net/archive/](https://jdk.java.net/archive/) | grep -Eo "[https://download.java.net/java/GA/jdk17](https://download.java.net/java/GA/jdk17)[^\"]+${JDK_PATTERN}" | head -n 1)
    curl -s -o build_tools/jdk.tar.gz "$JDK_URL"
    tar -xf build_tools/jdk.tar.gz -C build_tools/jdk --strip-components=1
    [ "$OS_TYPE" = "Darwin" ] && export PATH="$(pwd)/build_tools/jdk/Contents/Home/bin:$PATH" || export PATH="$(pwd)/build_tools/jdk/bin:$PATH"
fi

echo "=> 2. Checking Android SDK..."
if [ -n "$ANDROID_HOME" ] && [ -f "$ANDROID_HOME/platforms/android-35/android.jar" ]; then
    echo "   [System] Android SDK 35 found at $ANDROID_HOME."
    ANDROID_JAR="$ANDROID_HOME/platforms/android-35/android.jar"
    D8_CMD="$ANDROID_HOME/build-tools/35.0.0/d8"
    AAPT_CMD="$ANDROID_HOME/build-tools/35.0.0/aapt"
    APKSIGNER_CMD="$ANDROID_HOME/build-tools/35.0.0/apksigner"
else
    echo "   [Local] Android SDK 35 missing. Fetching dynamically..."
    mkdir -p build_tools/sdk
    CMD_OS=$([ "$(uname -s)" = "Darwin" ] && echo "mac" || echo "linux")
    SDK_URL=$(curl -s [https://developer.android.com/studio](https://developer.android.com/studio) | grep -Eo "[https://dl.google.com/android/repository/commandlinetools-$](https://dl.google.com/android/repository/commandlinetools-$){CMD_OS}-[0-9]*_latest\.zip" | sort -u | head -n 1)
    curl -s -o build_tools/cmdline.zip "$SDK_URL"
    unzip -q build_tools/cmdline.zip -d build_tools/sdk
    mkdir -p build_tools/sdk/cmdline-tools/latest
    mv build_tools/sdk/cmdline-tools/bin build_tools/sdk/cmdline-tools/lib build_tools/sdk/cmdline-tools/source.properties build_tools/sdk/cmdline-tools/latest/
    yes | build_tools/sdk/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null
    build_tools/sdk/cmdline-tools/latest/bin/sdkmanager "platforms;android-35" "build-tools;35.0.0" > /dev/null
    
    ANDROID_JAR="build_tools/sdk/platforms/android-35/android.jar"
    D8_CMD="build_tools/sdk/build-tools/35.0.0/d8"
    AAPT_CMD="build_tools/sdk/build-tools/35.0.0/aapt"
    APKSIGNER_CMD="build_tools/sdk/build-tools/35.0.0/apksigner"
fi

echo "=> 3. Checking Shizuku Libs..."
if [ ! -f "shizuku_libs/shizuku-api.jar" ]; then
    cd shizuku_libs
    for lib in api provider shared aidl; do
        curl -sO "[https://repo1.maven.org/maven2/dev/rikka/shizuku/$lib/13.1.5/$lib-13.1.5.aar](https://repo1.maven.org/maven2/dev/rikka/shizuku/$lib/13.1.5/$lib-13.1.5.aar)"
        unzip -q -j "$lib-13.1.5.aar" classes.jar -d . && mv classes.jar "shizuku-$lib.jar"
        rm "$lib-13.1.5.aar"
    done
    cd ..
else
    echo "   [System] Shizuku libs already present."
fi

echo "=> 4. Compiling and Signing..."
rm -f classes.dex unsigned.apk ShizukuAudioRouter.apk

javac -cp "${ANDROID_JAR}:shizuku_libs/shizuku-api.jar:shizuku_libs/shizuku-provider.jar:shizuku_libs/shizuku-shared.jar:shizuku_libs/shizuku-aidl.jar" -source 1.8 -target 1.8 -d . src/com/custom/audiorouter/*.java

$D8_CMD --lib "$ANDROID_JAR" --output . com/custom/audiorouter/*.class shizuku_libs/shizuku-aidl.jar shizuku_libs/shizuku-api.jar shizuku_libs/shizuku-provider.jar shizuku_libs/shizuku-shared.jar

$AAPT_CMD package -f -M AndroidManifest.xml -S res -I "$ANDROID_JAR" -F unsigned.apk --min-sdk-version 26 --target-sdk-version 35

jar uf unsigned.apk classes.dex

if [ ! -f dummy.keystore ]; then
    keytool -genkey -v -keystore dummy.keystore -alias dummy -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US" > /dev/null
fi

$APKSIGNER_CMD sign --ks dummy.keystore --ks-pass pass:android unsigned.apk

mv unsigned.apk ShizukuAudioRouter.apk
rm -rf com classes.dex

echo ""
echo "==========================================================="
echo "✅ SUCCESS! Your file is ready: ShizukuAudioRouter.apk"
echo "==========================================================="
