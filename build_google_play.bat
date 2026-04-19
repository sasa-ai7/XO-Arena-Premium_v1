@echo off
REM ============================================
REM Google Play Build Script
REM ============================================
REM This script builds the app bundle for Google Play Store upload
REM
REM Usage: build_google_play.bat
REM
REM The script executes:
REM   1. flutter clean - Cleans previous build artifacts
REM   2. flutter pub get - Fetches dependencies
REM   3. flutter build appbundle --release - Builds release app bundle
REM
REM ============================================

echo.
echo ============================================
echo Building App Bundle for Google Play Store
echo ============================================
echo.

REM Check if Flutter is available
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter is not in PATH. Please ensure Flutter is installed and added to PATH.
    pause
    exit /b 1
)

REM Step 1: Clean previous builds
echo [1/3] Cleaning previous build artifacts...
flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: flutter clean failed!
    pause
    exit /b 1
)
echo ✓ Clean completed successfully
echo.

REM Step 2: Get dependencies
echo [2/3] Fetching dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: flutter pub get failed!
    pause
    exit /b 1
)
echo ✓ Dependencies fetched successfully
echo.

REM Step 3: Build app bundle
echo [3/3] Building release app bundle...
echo.
echo NOTE: If your app requires Firebase API keys, add them as --dart-define flags:
echo   --dart-define=ANDROID_API_KEY=your_key ^
echo   --dart-define=ANDROID_APP_ID=your_app_id ^
echo   --dart-define=ANDROID_MESSAGING_SENDER_ID=your_sender_id ^
echo   --dart-define=ANDROID_PROJECT_ID=your_project_id ^
echo   --dart-define=ANDROID_STORAGE_BUCKET=your_storage_bucket
echo.

flutter build appbundle --release
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: flutter build appbundle failed!
    echo.
    echo Troubleshooting:
    echo - Ensure all Firebase API keys are provided if required
    echo - Check that android/key.properties exists and is configured
    echo - Verify keystore file exists at android/xo-release.keystore
    echo - See BUILD_INSTRUCTIONS.md for more details
    pause
    exit /b 1
)

echo.
echo ============================================
echo ✓ Build completed successfully!
echo ============================================
echo.
echo App bundle location:
echo   build\app\outputs\bundle\release\app-release.aab
echo.
echo You can now upload this file to Google Play Console.
echo.
pause
