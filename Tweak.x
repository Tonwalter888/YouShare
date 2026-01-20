#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>

#define TweakKey @"YouShare"

@interface YTMainAppVideoPlayerOverlayViewController (YouShare)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouShare)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouShare)
- (void)didPressYouShare;
@end

@interface YTMainAppControlsOverlayView (YouShare)
- (void)didPressYouShare:(id)arg;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouShare)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
- (void)didPressYouShare:(id)arg;
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

// For UIKit localizations
static inline NSString *YSLocalized(NSString *key) {
    return NSLocalizedStringFromTableInBundle(
        key,
        nil,
        YouShareBundle() ?: [NSBundle mainBundle],
        nil
    );
}

%group Main
%hook YTPlayerViewController
%new
- (void)didPressYouShare {
    if (!self.currentVideoID)
        return;

    if (self.isPlayingAd)
        return;

    // Prepare video link
    NSString *baseURL =
        [NSString stringWithFormat:@"https://youtube.com/watch?v=%@", self.currentVideoID];
    NSInteger seconds = (NSInteger)floor(self.currentVideoMediaTime);
    NSString *timestampURL =
        [NSString stringWithFormat:@"%@&t=%lds", baseURL, (long)seconds];

    // Create UIKit action sheet
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    // Copy URL
    UIAlertAction *copyURL =
        [UIAlertAction actionWithTitle:YSLocalized(@"COPY_URL")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
        UIPasteboard.generalPasteboard.string = baseURL;
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:
                [%c(YTHUDMessage)
                    messageWithText:YSLocalized(@"URL_COPIED")]];
    }];

    // Copy URL with timestamp
    UIAlertAction *copyTimestamp =
        [UIAlertAction actionWithTitle:YSLocalized(@"COPY_URL_TIMESTAMP")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
        UIPasteboard.generalPasteboard.string = timestampURL;
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:
                [%c(YTHUDMessage)
                    messageWithText:YSLocalized(@"URL_TIMESTAMP_COPIED")]];
    }];

    // Cancel
    UIAlertAction *cancel =
        [UIAlertAction actionWithTitle:YSLocalized(@"CANCEL")
                                 style:UIAlertActionStyleCancel
                               handler:nil];
    [alert addAction:copyURL];
    [alert addAction:copyTimestamp];
    [alert addAction:cancel];

    UIViewController *presenter =
        (UIViewController *)[self activeVideoPlayerOverlay];
    if (!presenter) return;

    // Prevent the dialog crashes on iPad
    UIPopoverPresentationController *popover =
        alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = presenter.view;
        popover.sourceRect = presenter.view.bounds;
        popover.permittedArrowDirections = 0; // Keeps the dialog centered,I still can't find the proper way to get it shows under the share button.
    }
    [presenter presentViewController:alert animated:YES completion:nil];
}

%end
%end

/**
  * Adds a share button to the top area in the video player overlay
  */
%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? shareImage(@"3") : %orig;
}

// Custom method to handle the share button press
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
  * Adds a share button to the bottom area next to the fullscreen button
  */
%group Bottom
%hook YTInlinePlayerBarContainerView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? shareImage(@"3") : %orig;
}

// Custom method to handle the share button press
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
        AccessibilityLabelKey: @"YouShare",
        SelectorKey: @"didPressYouShare:",
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
}
