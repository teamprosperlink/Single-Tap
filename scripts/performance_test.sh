#!/bin/bash

echo "🚀 Flutter Performance Testing Suite"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run performance tests
run_performance_test() {
    echo -e "\n${YELLOW}Running $1...${NC}"
    shift
    "$@"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Test completed successfully${NC}"
    else
        echo -e "${RED}✗ Test failed${NC}"
    fi
}

# 1. Build Size Analysis
echo -e "\n${YELLOW}1. APP SIZE ANALYSIS${NC}"
echo "------------------------"
flutter build apk --analyze-size
echo -e "${GREEN}Check build/app-size-analysis.json for detailed breakdown${NC}"

# 2. Startup Time Analysis
echo -e "\n${YELLOW}2. STARTUP TIME ANALYSIS${NC}"
echo "-------------------------"
flutter run --trace-startup --profile --no-hot
echo -e "${GREEN}Timeline saved to build/startup_timeline.json${NC}"
echo "Open chrome://tracing and load the JSON file to analyze"

# 3. Integration Tests
echo -e "\n${YELLOW}3. INTEGRATION PERFORMANCE TESTS${NC}"
echo "---------------------------------"
flutter test integration_test/performance_test.dart

# 4. Memory Profiling
echo -e "\n${YELLOW}4. MEMORY PROFILING${NC}"
echo "--------------------"
echo "Starting app with memory profiling..."
flutter run --profile --trace-skia

# 5. DevTools
echo -e "\n${YELLOW}5. LAUNCHING DEVTOOLS${NC}"
echo "----------------------"
flutter pub global activate devtools
flutter pub global run devtools

echo -e "\n${GREEN}Performance testing suite completed!${NC}"
echo "======================================="
echo ""
echo "📊 Next Steps:"
echo "1. Open DevTools at http://127.0.0.1:9100"
echo "2. Connect to your running app"
echo "3. Use the Performance tab to record and analyze frames"
echo "4. Check Memory tab for leaks"
echo "5. Review Network tab for API performance"
echo ""
echo "📈 Performance Targets:"
echo "• Frame rendering: < 16ms (60 FPS)"
echo "• Startup time: < 2 seconds"
echo "• Memory usage: < 150MB for normal usage"
echo "• APK size: < 30MB"