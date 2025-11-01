@echo off
echo Cleaning project...
flutter clean

echo Getting dependencies...
flutter pub get

echo Building APK...
flutter build apk --debug

echo Build completed!
pause
