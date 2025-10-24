#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>

#define TweakKey @"YouShare"

@interface YTMainAppVideoPlayerOverlayViewController (YouShare)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouShare)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouShare)
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, strong) NSString *currentVideoID;
- (void)didPressYouShare;
@end

@interface YTMainAppControlsOverlayView (YouShare)
@property (nonatomic, assign) YTPlayerViewController *playerViewController;
- (void)didPressYouTimeStamp:(id)arg;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouTimeStamp)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
- (void)didPressYouTimeStamp:(id)arg;
@end


// For displaying snackbars - @theRealfoxster
@interface YTHUDMessage : NSObject
+ (id)messageWithText:(id)text;
- (void)setAction:(id)action;
@end

@interface GOOHUDMessageAction : NSObject
- (void)setTitle:(NSString *)title;
- (void)setHandler:(void (^)(id))handler;
@end

@interface GOOHUDManagerInternal : NSObject
- (void)showMessageMainThread:(id)message;
+ (id)sharedInstance;
@end

NSBundle *YouShareBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}

static UIImage *shareImage(NSString *qualityLabel) {
    return [%c(QTMIcon) tintImage:[UIImage imageNamed:[NSString stringWithFormat:@"Share@%@", qualityLabel] inBundle: YouShareBundle() compatibleWithTraitCollection:nil] color:[%c(YTColor) white1]];
}

%group Main
%hook YTPlayerViewController
%new
- (void)didPressYouShare {
    if (self.currentVideoID) {
        NSString *videoId = [NSString stringWithFormat:@"https://youtube.com/watch?v=%@", self.currentVideoID];

        // Copy to clipboard
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:videoId];

        // Show HUD
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:[%c(YTHUDMessage) messageWithText:@"URL copied to clipboard"]];
    } else {
        NSLog(@"[YouShare] No video ID available");
    }
}
%end
%end

/**
  * Adds a timestamp copy button to the top area in the video player overlay
  */
%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? timestampImage(@"3") : %orig;
}

// Custom method to handle the timestamp button press
%new(v@:@)
- (void)didPressYouShare:(id)arg {
    // Call our custom method in the YTPlayerViewController class - this is 
    // directly accessible in the self.playerViewController property
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
    if (playerViewController) {
        [playerViewController didPressYouShare];
    }
}

%end
%end

/**
  * Adds a timestamp copy button to the bottom area next to the fullscreen button
  */
%group Bottom
%hook YTInlinePlayerBarContainerView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? shareImage(@"3") : %orig;
}

%new(v@:@)
- (void)didPressYouShare:(id)arg {
    YTInlinePlayerBarController *delegate = self.delegate;
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    if (parentViewController) {
        [parentViewController didPressYouShare];
    }
}
%end
%end

%ctor {
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"Copy Video URL",
        SelectorKey: @"didPressYouShare:",
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
}
