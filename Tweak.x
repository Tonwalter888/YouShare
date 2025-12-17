#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTActionSheetController.h>
#import <YouTubeHeader/YTActionSheetAction.h>

#define TweakKey @"YouShare"

@interface YTMainAppVideoPlayerOverlayViewController (YouShare)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouShare)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouShare)
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, assign) NSString *currentVideoID;
- (void)didPressYouShare;
@end

@interface YTMainAppControlsOverlayView (YouShare)
@property (nonatomic, assign) YTPlayerViewController *playerViewController;
- (void)didPressYouShare:(id)arg;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouShare)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
- (void)didPressYouShare:(id)arg;
@end

@interface YTActionSheetController (YouShare)
- (void)addAction:(id)action;
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

static inline NSString *YSLocalized(NSString *key, NSString *comment) {
    return NSLocalizedStringFromTableInBundle(
        key,
        nil,
        YouShareBundle() ?: [NSBundle mainBundle],
        comment
    );
}

%group Main
%hook YTPlayerViewController

%new
- (void)didPressYouShare {

    if (!self.currentVideoID || self.isPlayingAd)
        return;

    // URLs
    NSString *baseURL =
        [NSString stringWithFormat:@"https://youtube.com/watch?v=%@", self.currentVideoID];

    NSInteger seconds = (NSInteger)floor(self.currentVideoMediaTime);
    NSString *timestampURL =
        [NSString stringWithFormat:@"%@&t=%lds", baseURL, (long)seconds];

    // Get active overlay (for anchor)
    id overlay = [self activeVideoPlayerOverlay];
    if (!overlay || ![overlay respondsToSelector:@selector(videoPlayerOverlayView)])
        return;

    YTMainAppVideoPlayerOverlayView *overlayView =
        [overlay videoPlayerOverlayView];
    if (!overlayView)
        return;

    // Pick anchor view (top controls preferred)
    UIView *anchorView = nil;
    if ([overlayView respondsToSelector:@selector(controlsOverlayView)]) {
        anchorView = [overlayView controlsOverlayView];
    }
    if (!anchorView && overlayView.playerBar) {
        anchorView = overlayView.playerBar;
    }
    if (!anchorView)
        return;

    // Create UIKit action sheet
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    // Copy URL
    UIAlertAction *copyURL =
        [UIAlertAction actionWithTitle:YSLocalized(@"COPY_URL", nil)
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {

        UIPasteboard.generalPasteboard.string = baseURL;

        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:
                [%c(YTHUDMessage)
                    messageWithText:YSLocalized(@"URL_COPIED", nil)]];
    }];

    // Copy URL with timestamp
    UIAlertAction *copyTimestamp =
        [UIAlertAction actionWithTitle:YSLocalized(@"COPY_URL_TIMESTAMP", nil)
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {

        UIPasteboard.generalPasteboard.string = timestampURL;

        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:
                [%c(YTHUDMessage)
                    messageWithText:YSLocalized(@"URL_TIMESTAMP_COPIED", nil)]];
    }];

    // Cancel
    UIAlertAction *cancel =
        [UIAlertAction actionWithTitle:YSLocalized(@"CANCEL", @"Cancel")
                                 style:UIAlertActionStyleCancel
                               handler:nil];

    [alert addAction:copyURL];
    [alert addAction:copyTimestamp];
    [alert addAction:cancel];

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = anchorView;
        popover.sourceRect = anchorView.bounds;
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }

    // Present from overlay controller
    [overlay presentViewController:alert animated:YES completion:nil];
}

%end
%end

/**
  * Adds a timestamp copy button to the top area in the video player overlay
  */
%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? shareImage(@"3") : %orig;
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

// Custom method to handle the timestamp button press
%new(v@:@)
- (void)didPressYouShare:(id)arg {
    // Navigate to the YTPlayerViewController class from here
    YTInlinePlayerBarController *delegate = self.delegate; // for @property
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"]; // for ivars
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    // Call our custom method in the YTPlayerViewController class
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
