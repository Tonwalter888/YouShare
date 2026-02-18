#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>

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
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}

static UIImage *shareIcon(NSString *qualityLabel) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = YT_SHARE;
    if ([icon respondsToSelector:@selector(iconImageWithColor:)]) {
        return [icon iconImageWithColor:[%c(YTColor) white1]];
    }
    if ([icon respondsToSelector:@selector(iconImageWithSelected:)]) {
        return [icon iconImageWithSelected:NO];
    }
    return nil;
}

static inline NSString *YSLocalizations(NSString *key) {
    return [YouShareBundle() localizedStringForKey:key value:nil table:nil];
}

%group Main
%hook YTPlayerViewController
%new
- (void)didPressYouShare {
    if (!self.currentVideoID || self.isPlayingAd) return;

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
        [UIAlertAction actionWithTitle:YSLocalizations(@"COPY_URL")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
        UIPasteboard.generalPasteboard.string = baseURL;
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:
                [%c(YTHUDMessage)
                    messageWithText:YSLocalizations(@"URL_COPIED")]];
    }];

    // Copy URL with timestamp
    UIAlertAction *copyTimestamp =
        [UIAlertAction actionWithTitle:YSLocalizations(@"COPY_URL_TIMESTAMP")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
        UIPasteboard.generalPasteboard.string = timestampURL;
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:
                [%c(YTHUDMessage)
                    messageWithText:YSLocalizations(@"URL_TIMESTAMP_COPIED")]];
    }];

    // Cancel
    UIAlertAction *cancel =
        [UIAlertAction actionWithTitle:YSLocalizations(@"CANCEL")
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
    return [tweakId isEqualToString:TweakKey] ? shareIcon(@"3") : %orig;
}

// Custom method to handle the share button press
%new(v@:@)
- (void)didPressYouShare:(id)arg {
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
    return [tweakId isEqualToString:TweakKey] ? shareIcon(@"3") : %orig;
}

// Custom method to handle the share button press
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
        AccessibilityLabelKey: @"YouShare",
        SelectorKey: @"didPressYouShare:",
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
}
