#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"

#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>

#define TweakKey @"YouShare"

#pragma mark - Interfaces

@interface YTMainAppVideoPlayerOverlayViewController (YouShare)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouShare)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouShare)
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, assign) NSString *currentVideoID;
@property (nonatomic, assign) BOOL isPlayingAd;
- (id)activeVideoPlayerOverlay;
- (void)didPressYouShare;
@end

@interface YTMainAppControlsOverlayView (YouShare)
@property (nonatomic, assign) YTPlayerViewController *playerViewController;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YouShare)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
@end

@interface YTHUDMessage : NSObject
+ (id)messageWithText:(id)text;
@end

@interface GOOHUDManagerInternal : NSObject
+ (id)sharedInstance;
- (void)showMessageMainThread:(id)message;
@end

#pragma mark - Bundle / Utils

NSBundle *YouShareBundle(void) {
    static NSBundle *bundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path =
            [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"]
            ?: [NSString stringWithFormat:
                ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey];
        bundle = [NSBundle bundleWithPath:path];
    });
    return bundle;
}

static inline NSString *YSLocalized(NSString *key) {
    return NSLocalizedStringFromTableInBundle(key, nil,
        YouShareBundle() ?: [NSBundle mainBundle], nil);
}

static UIImage *YSShareImage(void) {
    return [%c(QTMIcon)
        tintImage:[UIImage imageNamed:@"Share@3"
                             inBundle:YouShareBundle()
        compatibleWithTraitCollection:nil]
        color:[%c(YTColor) white1]];
}

#pragma mark - Button Finder (IMPORTANT)

static UIView *YSFindButton(UIView *view) {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            if ([((UIButton *)sub).accessibilityLabel
                    isEqualToString:@"Copy Video URL"]) {
                return sub;
            }
        }
        UIView *found = YSFindButton(sub);
        if (found) return found;
    }
    return nil;
}

#pragma mark - Main Logic

%group Main
%hook YTPlayerViewController

%new
- (void)didPressYouShare {

    if (!self.currentVideoID || self.isPlayingAd) return;

    NSInteger seconds = (NSInteger)floor(self.currentVideoMediaTime);
    NSString *baseURL =
        [NSString stringWithFormat:@"https://youtube.com/watch?v=%@",
            self.currentVideoID];
    NSString *timestampURL =
        [NSString stringWithFormat:@"%@&t=%lds", baseURL, (long)seconds];

    id overlay = [self activeVideoPlayerOverlay];
    if (![overlay respondsToSelector:@selector(videoPlayerOverlayView)]) return;

    YTMainAppVideoPlayerOverlayView *overlayView =
        [overlay videoPlayerOverlayView];
    if (!overlayView) return;

    UIView *anchorView =
        YSFindButton(overlayView) ?: overlayView;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:
        [UIAlertAction actionWithTitle:YSLocalized(@"COPY_URL")
                                 style:UIAlertActionStyleDefault
                               handler:^(__unused UIAlertAction *a) {
        UIPasteboard.generalPasteboard.string = baseURL;
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:
                [%c(YTHUDMessage) messageWithText:
                    YSLocalized(@"URL_COPIED")]];
    }]];

    [alert addAction:
        [UIAlertAction actionWithTitle:YSLocalized(@"COPY_URL_TIMESTAMP")
                                 style:UIAlertActionStyleDefault
                               handler:^(__unused UIAlertAction *a) {
        UIPasteboard.generalPasteboard.string = timestampURL;
        [[%c(GOOHUDManagerInternal) sharedInstance]
            showMessageMainThread:
                [%c(YTHUDMessage) messageWithText:
                    YSLocalized(@"URL_TIMESTAMP_COPIED")]];
    }]];

    [alert addAction:
        [UIAlertAction actionWithTitle:YSLocalized(@"CANCEL")
                                 style:UIAlertActionStyleCancel
                               handler:nil]];

    UIPopoverPresentationController *popover =
        alert.popoverPresentationController;
    if (popover) {
        popover.sourceView = anchorView;
        popover.sourceRect = anchorView.bounds;
        popover.permittedArrowDirections =
            UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
    }

    [overlay presentViewController:alert animated:YES completion:nil];
}

%end
%end

#pragma mark - Top Button

%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tid {
    return [tid isEqualToString:TweakKey] ? YSShareImage() : %orig;
}

%new(v@:@)
- (void)didPressYouShare:(id)arg {
    YTMainAppVideoPlayerOverlayView *view =
        (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTPlayerViewController *vc =
        view.delegate.parentViewController;
    [vc didPressYouShare];
}

%end
%end

#pragma mark - Bottom Button

%group Bottom
%hook YTInlinePlayerBarContainerView

- (UIImage *)buttonImage:(NSString *)tid {
    return [tid isEqualToString:TweakKey] ? YSShareImage() : %orig;
}

%new(v@:@)
- (void)didPressYouShare:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *overlay =
        [self.delegate valueForKey:@"_delegate"];
    [overlay.parentViewController didPressYouShare];
}

%end
%end

#pragma mark - Init

%ctor {
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey : @"Copy Video URL",
        SelectorKey : @"didPressYouShare:",
    });

    %init(Main);
    %init(Top);
    %init(Bottom);
}
