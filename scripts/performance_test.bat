@echo off
echo ============================================
echo Flutter Performance Testing Suite
echo ============================================

echo.
echo 1. APP SIZE ANALYSIS
echo ------------------------
flutter build apk --analyze-size
echo Check build\app-size-analysis.json for detailed breakdown

echo.
echo 2. STARTUP TIME ANALYSIS  
echo -------------------------
echo Starting app with startup trace...
flutter run --trace-startup --profile --no-hot
echo Timeline saved to build\startup_timeline.json
echo Open chrome://tracing and load the JSON file to analyze

echo.
echo 3. INTEGRATION PERFORMANCE TESTS
echo ---------------------------------
flutter test test\performance\scroll_performance_test.dart

echo.
echo 4. MEMORY PROFILING
echo --------------------
echo Starting app with memory profiling...
start cmd /k flutter run --profile --trace-skia

echo.
echo 5. LAUNCHING DEVTOOLS
echo ----------------------
flutter pub global activate devtools
start cmd /k flutter pub global run devtools

echo.
echo ============================================
echo Performance testing suite completed!
echo ============================================
echo.
echo Next Steps:
echo 1. Open DevTools at http://127.0.0.1:9100
echo 2. Connect to your running app
echo 3. Use the Performance tab to record and analyze frames
echo 4. Check Memory tab for leaks
echo 5. Review Network tab for API performance
echo.
echo Performance Targets:
echo - Frame rendering: Less than 16ms (60 FPS)
echo - Startup time: Less than 2 seconds
echo - Memory usage: Less than 150MB for normal usage
echo - APK size: Less than 30MB
echo.
pause