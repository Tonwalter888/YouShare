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

static UIImage *timestampImage(NSString *qualityLabel) {
    return [%c(QTMIcon) tintImage:[UIImage imageNamed:[NSString stringWithFormat:@"Timestamp@%@", qualityLabel] inBundle:YouShareBundle() compatibleWithTraitCollection:nil] color:[%c(YTColor) white1]];
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
    if (!self.currentVideoID)
        return;

    // URL
    NSString *baseURL =
        [NSString stringWithFormat:@"https://youtube.com/watch?v=%@", self.currentVideoID];
    NSInteger seconds = (NSInteger)floor(self.currentVideoMediaTime);
    NSString *timestampURL =
        [NSString stringWithFormat:@"%@&t=%lds", baseURL, (long)seconds];

    // Localized strings
    NSString *copyURLTitle =
        YSLocalized(@"COPY_URL", @"Action title: Copy URL");

    NSString *copyTimestampTitle =
        YSLocalized(@"COPY_URL_TIMESTAMP", @"Action title: Copy URL with timestamp");

    NSString *urlCopiedMsg =
        YSLocalized(@"URL_COPIED", @"Toast when URL is copied");

    NSString *timestampCopiedMsg =
        YSLocalized(@"URL_TIMESTAMP_COPIED", @"Toast when URL with timestamp is copied");

    // Action sheet
    YTActionSheetController *sheet =
        [%c(YTActionSheetController) actionSheetController];
    UIImage *shareIcon = shareImage(@"3");
    UIImage *timestampIcon = timestampImage(@"3");

    // Copy URL
    YTActionSheetAction *copyURL =
        [%c(YTActionSheetAction)
            actionWithTitle:copyURLTitle
            iconImage:shareIcon
            style:0
            handler:^(YTActionSheetAction *action) {
                UIPasteboard.generalPasteboard.string = baseURL;
                [[%c(GOOHUDManagerInternal) sharedInstance]
                    showMessageMainThread:
                        [%c(YTHUDMessage) messageWithText:urlCopiedMsg]];
                action.shouldDismissOnAction = YES;
            }];
    [sheet addAction:copyURL];

    // Copy URL with timestamp
    YTActionSheetAction *copyTimestamp =
        [%c(YTActionSheetAction)
            actionWithTitle:copyTimestampTitle
            iconImage:timestampIcon
            style:0
            handler:^(YTActionSheetAction *action) {
                UIPasteboard.generalPasteboard.string = timestampURL;
                [[%c(GOOHUDManagerInternal) sharedInstance]
                    showMessageMainThread:
                        [%c(YTHUDMessage) messageWithText:timestampCopiedMsg]];
                action.shouldDismissOnAction = YES;
            }];
    [sheet addAction:copyTimestamp];

    // Cancel button
    [sheet addCancelActionIfNeeded];

    UIViewController *presenter = self;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    [sheet presentFromViewController:presenter
                            animated:YES
                          completion:nil];
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
