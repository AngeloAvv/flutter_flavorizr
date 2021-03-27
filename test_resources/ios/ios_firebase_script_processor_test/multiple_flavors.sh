if [ "$CONFIGURATION" == "Debug-apple" ] || [ "$CONFIGURATION" == "Release-apple" ]; then
  cp Runner/apple/GoogleService-Info.plist Runner/GoogleService-Info.plist
elif [ "$CONFIGURATION" == "Debug-banana" ] || [ "$CONFIGURATION" == "Release-banana" ]; then
  cp Runner/banana/GoogleService-Info.plist Runner/GoogleService-Info.plist
elif [ "$CONFIGURATION" == "Debug-pear" ] || [ "$CONFIGURATION" == "Release-pear" ]; then
  cp Runner/pear/GoogleService-Info.plist Runner/GoogleService-Info.plist
fi
