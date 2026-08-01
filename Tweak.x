// Hold to copy button original codes - Sohday67 https://github.com/Sohday67/YouTimeStamp/blob/eafb1f583500e8d5ab84b25487e5f3d55cba5d65/Tweak.x
#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTDefaultSheetController.h>
#import <YouTubeHeader/YTActionSheetAction.h>

#define TweakKey @"YouShare"
#define HoldToCopyKey @"YouShareHoldToCopy"

@interface YTPlayerViewController (YouShare)
- (void)didPressYouShare:(UIView *)sourceView;
- (void)didLongPressYouShare;
@end

@interface YTMainAppControlsOverlayView (YouShare)
- (void)didPressYouShare:(id)arg;
- (void)didLongPressYouShare:(UILongPressGestureRecognizer *)gesture;
@end

@interface YTInlinePlayerBarContainerView (YouShare)
- (void)didPressYouShare:(id)arg;
- (void)didLongPressYouShare:(UILongPressGestureRecognizer *)gesture;
@end

@interface YTDefaultSheetController (YouShare)
+ (instancetype)sheetControllerWithParentResponder:(id)parentResponder;
- (void)addAction:(YTActionSheetAction *)action;
- (void)presentFromView:(UIView *)view animated:(BOOL)animated completion:(void (^)(void))completion;
@end

static NSBundle *YouShareBundle() {
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

static NSBundle *tweakBundle = nil;

static UIImage *YouShareYTIconImage(NSInteger iconType, BOOL useLabelColor) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    UIImage *image;
    if (useLabelColor) {
        UIColor *targetColor;
        if (@available(iOS 13.0, *)) {
            targetColor = [UIColor labelColor];
        } else {
            UIUserInterfaceStyle style = UIScreen.mainScreen.traitCollection.userInterfaceStyle;
            if (style == UIUserInterfaceStyleDark) {
                targetColor = [UIColor whiteColor];
            } else {
                targetColor = [UIColor blackColor];
            }
        }
        image = [icon iconImageWithColor:targetColor];
    } else {
        image = [icon iconImageWithColor:[UIColor whiteColor]];
    }
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static BOOL HoldToCopyKeyEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HoldToCopyKey];
}

static void addLongPressGestureToTheButton(YTQTMButton *button, id target, SEL selector) {
    if (button) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:selector];
        longPress.minimumPressDuration = 0.45;
        [button addGestureRecognizer:longPress];
    }
}

%group Main
%hook YTPlayerViewController
// Normal logic (popup UI) and Copy URL without timestamp logic
%new
- (void)didPressYouShare:(UIView *)sourceView {
    if (!self.currentVideoID) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"ERROR");
        alertView.subtitle = LOC(@"ERROR_VIDEOID");
        [alertView show];
        return;
    } else if (self.isPlayingAd) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"ERROR");
        alertView.subtitle = LOC(@"ERROR_ADS");
        [alertView show];
        return;
    }

    // Prepare video link
    NSString *videoURL = [NSString stringWithFormat:@"https://youtube.com/watch?v=%@", self.currentVideoID];
    NSInteger seconds = (NSInteger)floor(self.currentVideoMediaTime);
    NSString *timestampURL = [NSString stringWithFormat:@"%@&t=%lds", videoURL, (long)seconds];

    if (HoldToCopyKeyEnabled()) {
        // Copy the link to clipboard
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:videoURL];
        // Show snackbar
        [[%c(GOOHUDManagerInternal) sharedInstance] 
            showMessageMainThread:
                [%c(YTHUDMessage) messageWithText:LOC(@"URL_COPIED")]];
    } else {
        UIViewController *presenter = (UIViewController *)[self activeVideoPlayerOverlay];
        YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:presenter];

        YTActionSheetAction *copyURL = [%c(YTActionSheetAction) actionWithTitle:LOC(@"COPY_URL") iconImage:YouShareYTIconImage(250, YES) style:0 handler:^(__unused YTActionSheetAction *action) {
            UIPasteboard.generalPasteboard.string = videoURL;
            [[%c(GOOHUDManagerInternal) sharedInstance]
                showMessageMainThread:
                    [%c(YTHUDMessage)
                        messageWithText:LOC(@"URL_COPIED")]];
        }];

        YTActionSheetAction *copyTimestamp = [%c(YTActionSheetAction) actionWithTitle:LOC(@"COPY_URL_TIMESTAMP") iconImage:YouShareYTIconImage(250, YES) style:0 handler:^(__unused YTActionSheetAction *action) {
            UIPasteboard.generalPasteboard.string = timestampURL;
            [[%c(GOOHUDManagerInternal) sharedInstance]
                showMessageMainThread:
                    [%c(YTHUDMessage)
                        messageWithText:LOC(@"URL_TIMESTAMP_COPIED")]];
        }];

        [sheet addAction:copyURL];
        [sheet addAction:copyTimestamp];

        [sheet presentFromView:sourceView animated:YES completion:nil];
    }
}

// Create a link with timestamp for long press
%new
- (void)didLongPressYouShare {
    if (HoldToCopyKeyEnabled()) {
        if (!self.currentVideoID) {
            YTAlertView *alertView = [%c(YTAlertView) infoDialog];
            alertView.title = LOC(@"ERROR");
            alertView.subtitle = LOC(@"ERROR_VIDEOID");
            [alertView show];
            return;
        } else if (self.isPlayingAd) {
            YTAlertView *alertView = [%c(YTAlertView) infoDialog];
            alertView.title = LOC(@"ERROR");
            alertView.subtitle = LOC(@"ERROR_ADS");
            [alertView show];
            return;
        }

        NSString *videoURL = [NSString stringWithFormat:@"https://youtu.be/%@", self.currentVideoID];
        NSInteger seconds = (NSInteger)floor(self.currentVideoMediaTime);
        NSString *timestampURL = [NSString stringWithFormat:@"%@&t=%lds", videoURL, (long)seconds];
        // Copy the link to clipboard
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:timestampURL];
        // Show snackbar
        [[%c(GOOHUDManagerInternal) sharedInstance] 
            showMessageMainThread:
                [%c(YTHUDMessage) messageWithText:LOC(@"URL_TIMESTAMP_COPIED")]];
    }
}

%end
%end

/**
  * Adds a share button to the top area in the video player overlay
  */
%group Top
%hook YTMainAppControlsOverlayView

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    addLongPressGestureToTheButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouShare:));
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    addLongPressGestureToTheButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouShare:));
    return self;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? YouShareYTIconImage(48, NO) : %orig;
}

// Custom method to handle the share button press
%new(v@:@)
- (void)didPressYouShare:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = [self valueForKey:@"_eventsDelegate"];
    YTPlayerViewController *playerViewController = (YTPlayerViewController *)mainOverlayController.parentViewController;
    UIView *button = self.overlayButtons[TweakKey];
    [playerViewController didPressYouShare:button];
}

// Custom method to handle long press on the share button
%new(v@:@)
- (void)didLongPressYouShare:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTMainAppVideoPlayerOverlayViewController *mainOverlayController = [self valueForKey:@"_eventsDelegate"];
        YTPlayerViewController *playerViewController = (YTPlayerViewController *)mainOverlayController.parentViewController;
        [playerViewController didLongPressYouShare];
    }
}

%end
%end

/**
  * Adds a share button to the bottom area next to the fullscreen button
  */
%group Bottom
%hook YTInlinePlayerBarContainerView

- (id)init {
    self = %orig;
    addLongPressGestureToTheButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouShare:));
    return self;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? YouShareYTIconImage(48, NO) : %orig;
}

// Custom method to handle the share button press
%new(v@:@)
- (void)didPressYouShare:(id)arg {
    YTMainAppVideoPlayerOverlayView *ov = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *ovcon = [ov valueForKey:@"_delegate"];
    YTPlayerViewController *parentViewController = (YTPlayerViewController *)ovcon.parentViewController;
    UIView *button = self.overlayButtons[TweakKey];
    [parentViewController didPressYouShare:button];
}

// Custom method to handle long press on the share button
%new(v@:@)
- (void)didLongPressYouShare:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTMainAppVideoPlayerOverlayView *ov = (YTMainAppVideoPlayerOverlayView *)self.superview;
        YTMainAppVideoPlayerOverlayViewController *ovcon = [ov valueForKey:@"_delegate"];
        YTPlayerViewController *parentViewController = (YTPlayerViewController *)ovcon.parentViewController;
        [parentViewController didLongPressYouShare];
    }
}

%end
%end

%ctor {
    tweakBundle = YouShareBundle();
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"YouShare",
        SelectorKey: @"didPressYouShare:",
        ExtraBooleanKeys: @[HoldToCopyKey],
    });
    %init(Main);
    %init(Top);
    %init(Bottom);
}