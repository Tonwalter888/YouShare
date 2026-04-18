// Hold to copy button original codes - Sohday67 https://github.com/Sohday67/YouTimeStamp/blob/eafb1f583500e8d5ab84b25487e5f3d55cba5d65/Tweak.x
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
#import <YouTubeHeader/YTAlertView.h>

#define TweakKey @"YouShare"
#define HoldToCopyKey @"YouShareHoldToCopy"

@interface YTMainAppVideoPlayerOverlayViewController (YouShare)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouShare)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouShare)
- (void)didPressYouShare:(UIView *)sourceView;
- (void)didLongPressYouShare;
@end

@interface YTMainAppControlsOverlayView (YouShare)
- (void)didPressYouShare:(id)arg;
- (void)didLongPressYouShare:(UILongPressGestureRecognizer *)gesture;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouShare)
- (void)didPressYouShare:(id)arg;
- (void)didLongPressYouShare:(UILongPressGestureRecognizer *)gesture;
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

static NSBundle *tweakBundle = nil;

static UIImage *shareIcon() {
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

static BOOL HoldToCopyKeyEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HoldToCopyKey];
}

static void addLongPressGestureToTheButton(YTQTMButton *button, id target, SEL selector) {
    if (button) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:selector];
        longPress.minimumPressDuration = 0.4;
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
        // Create UIKit action sheet
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        // Copy URL
        UIAlertAction *copyURL =
            [UIAlertAction actionWithTitle:LOC(@"COPY_URL")
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *a) {
            UIPasteboard.generalPasteboard.string = videoURL;
            [[%c(GOOHUDManagerInternal) sharedInstance]
                showMessageMainThread:
                    [%c(YTHUDMessage)
                        messageWithText:LOC(@"URL_COPIED")]];
        }];

        // Copy URL with timestamp
        UIAlertAction *copyTimestamp =
            [UIAlertAction actionWithTitle:LOC(@"COPY_URL_TIMESTAMP")
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *a) {
            UIPasteboard.generalPasteboard.string = timestampURL;
            [[%c(GOOHUDManagerInternal) sharedInstance]
                showMessageMainThread:
                    [%c(YTHUDMessage)
                        messageWithText:LOC(@"URL_TIMESTAMP_COPIED")]];
        }];

        // Cancel
        UIAlertAction *cancel =
            [UIAlertAction actionWithTitle:LOC(@"CANCEL")
                                     style:UIAlertActionStyleCancel
                                   handler:nil];
        [alert addAction:copyURL];
        [alert addAction:copyTimestamp];
        [alert addAction:cancel];

        UIViewController *presenter = (UIViewController *)[self activeVideoPlayerOverlay];
        // Prevent the dialog crashes on iPad
        UIPopoverPresentationController *popover = alert.popoverPresentationController;
        if (popover && sourceView) {
            popover.sourceView = sourceView;
            popover.sourceRect = sourceView.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
        }
        [presenter presentViewController:alert animated:YES completion:nil];
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
    if (self) {
        addLongPressGestureToTheButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouShare:));
    }
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    if (self) {
        addLongPressGestureToTheButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouShare:));
    }
    return self;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? shareIcon() : %orig;
}

// Custom method to handle the share button press
%new(v@:@)
- (void)didPressYouShare:(id)arg {
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
    UIView *button = self.overlayButtons[TweakKey];
    [playerViewController didPressYouShare:button];
}

// Custom method to handle long press on the share button
%new(v@:@)
- (void)didLongPressYouShare:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
        YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
        YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
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
    if (self) {
        addLongPressGestureToTheButton(self.overlayButtons[TweakKey], self, @selector(didLongPressYouShare:));
    }
    return self;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? shareIcon() : %orig;
}

// Custom method to handle the share button press
%new(v@:@)
- (void)didPressYouShare:(id)arg {
    YTInlinePlayerBarController *delegate = self.delegate;
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    UIView *button = self.overlayButtons[TweakKey];
    [parentViewController didPressYouShare:button];
}

// Custom method to handle long press on the share button
%new(v@:@)
- (void)didLongPressYouShare:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        YTInlinePlayerBarController *delegate = self.delegate;
        YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
        YTPlayerViewController *parentViewController = _delegate.parentViewController;
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