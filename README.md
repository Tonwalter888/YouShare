# YouShare
Have the ability to copy the YouTube video URL easier in the video controls overlay.

Please also uses/injects with [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) if you want to use this tweak.

## Building
1. Clone [Theos](https://github.com/theos/theos) along with its submodules.
2. Clone and copy [iOS 18.6 SDK](https://github.com/Tonwalter888/iOS-18.6-SDK) to ``$THEOS/sdks``.
3. Clone [YouTubeHeader](https://github.com/PoomSmart/YouTubeHeader) and [PSHeader](https://github.com/PoomSmart/PSHeader) into ``$THEOS/include``.
4. Cd into your theos folder and cd back ``cd ..``, then clone [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) there.
5. Clone YouShare, cd into it and run
- ``make clean package DEBUG=0 FINALPACKAGE=1`` For rootful jailbroken iOS (iOS >15 - checkra1n, Cydia)
- ``make clean package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`` For rootless jailbroken iOS (iOS 15+ - palera1n, Sileo, Zebra, Dolpamine, bakera1n, TrollStore)
- ``make clean package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide`` For roothide jailbroken iOS (iOS 15 - Dolpamine, Bootstrap)
