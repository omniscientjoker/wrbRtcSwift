#!/bin/bash

cd "/Users/jiangmiao/work_dict/aicode/simpleEyes/ios"

echo "===== Starting iOS Build ====="
echo "Working directory: $(pwd)"
echo ""

echo "===== Checking workspace ====="
ls -la SimpleEyes.xcworkspace 2>&1
echo ""

echo "===== Listing schemes ====="
xcodebuild -workspace SimpleEyes.xcworkspace -list 2>&1
echo ""

echo "===== Building project ====="
xcodebuild \
  -workspace SimpleEyes.xcworkspace \
  -scheme SimpleEyes \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  clean build \
  2>&1 | tee build_output.txt

echo ""
echo "===== Build completed ====="
echo "Exit code: $?"
echo ""
echo "===== Errors (if any) ====="
grep -i "error:" build_output.txt | head -20
