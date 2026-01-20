# YouShare
Have the ability to copy the YouTube video URL easier in the video controls overlay.

## Building
- Clone [Theos](https://github.com/theos/theos) along with its submodules.
- Clone and Copy [iOS 18.6 SDK](https://github.com/Tonwalter888/iOS-18.6-SDK) to ``$THEOS/sdks``.
- Cd into your theos folder and cd back ``cd ..``,then clone [YTVideoOverlay](https://github.com/PoomSmart/YTVideoOverlay) there.
- Clone YouShare,cd into it and run ``make clean package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless``. (You can remove the ``THEOS_PACKAGE_SCHEME=rootless`` part if you are using in jailbroken iOS.)
