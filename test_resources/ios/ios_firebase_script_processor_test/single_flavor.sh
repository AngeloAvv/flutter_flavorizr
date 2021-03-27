if [ "$CONFIGURATION" == "Debug-apple" ] || [ "$CONFIGURATION" == "Release-apple" ]; then
  cp Runner/apple/GoogleService-Info.plist Runner/GoogleService-Info.plist
fi
