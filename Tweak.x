#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"

#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>

#define TweakKey @"YouShare"

#pragma mark - YouTube Private Interfaces (CORRECT)

/**
 * NOTE:
 * These headers are intentionally incomplete in YouTubeHeader.
 * We must forward-declare the selectors that ACTUALLY exist at runtime.
 */

@interface YTActionSheetController : NSObject
@end

@interface YTActionSheetController (YouShare)
- (void)addAction:(id)action;
@end

@interface YTActionSheetAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title
                         handler:(void (^)(YTActionSheetAction *action))handler;
@end

@interface YTPlayerViewController : UIViewController
@property (nonatomic, copy) NSString *currentVideoID;
@property (nonatomic, assign) CGFloat currentVideoMediaTime;
@property (nonatomic, assign) BOOL isPlayingAd;
- (id)activeVideoPlayerOverlay;
- (void)didPressYouShare;
@end

@interface YTMainAppVideoPlayerOverlayViewController (YouShare)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
- (void)presentActionSheet:(id)sheet;
@end

@interface YTMainAppControlsOverlayView : UIView
@property (nonatomic, weak) YTPlayerViewController *playerViewController;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView : UIView
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
@end

#pragma mark - Bundle / Localization

static NSBundle *YouShareBundle(void) {
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
    return NSLocalizedStringFromTableInBundle(
        key, nil,
        YouShareBundle() ?: [NSBundle mainBundle], nil);
}

static UIImage *YSShareImage(void) {
    return [%c(QTMIcon)
        tintImage:[UIImage imageNamed:@"Share@3"
                             inBundle:YouShareBundle()
        compatibleWithTraitCollection:nil]
        color:[%c(YTColor) white1]];
}

#pragma mark - Main Logic (Native YouTube Menu)

%group Main
%hook YTPlayerViewController

%new
- (void)didPressYouShare {

    // Safety checks
    if (!self.currentVideoID) return;
    if (self.isPlayingAd) return;

    NSInteger seconds =
        (NSInteger)floor(self.currentVideoMediaTime);

    NSString *baseURL =
        [NSString stringWithFormat:
            @"https://youtube.com/watch?v=%@",
            self.currentVideoID];

    NSString *timestampURL =
        [NSString stringWithFormat:
            @"%@&t=%lds", baseURL, (long)seconds];

    YTMainAppVideoPlayerOverlayViewController *overlay =
        [self activeVideoPlayerOverlay];

    if (!overlay) return;

    // Native YouTube action sheet
    YTActionSheetController *sheet =
        [[%c(YTActionSheetController) alloc] init];

    // Copy URL
    YTActionSheetAction *copyURL =
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"COPY_URL")
                    handler:^(__unused YTActionSheetAction *a) {

        UIPasteboard.generalPasteboard.string = baseURL;
    }];

    // Copy URL with timestamp
    YTActionSheetAction *copyTimestamp =
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"COPY_URL_TIMESTAMP")
                    handler:^(__unused YTActionSheetAction *a) {

        UIPasteboard.generalPasteboard.string = timestampURL;
    }];

    // Cancel
    YTActionSheetAction *cancel =
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"CANCEL")
                    handler:nil];

    [sheet addAction:copyURL];
    [sheet addAction:copyTimestamp];
    [sheet addAction:cancel];

    // IMPORTANT: YouTube presenter (NOT UIKit)
    [overlay presentActionSheet:sheet];
}

%end
%end

#pragma mark - Top Overlay Button

%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey]
        ? YSShareImage()
        : %orig;
}

%new(v@:@)
- (void)didPressYouShare:(id)arg {

    YTMainAppVideoPlayerOverlayView *overlayView =
        (YTMainAppVideoPlayerOverlayView *)self.superview;

    YTPlayerViewController *vc =
        overlayView.delegate.parentViewController;

    [vc didPressYouShare];
}

%end
%end

#pragma mark - Bottom Bar Button

%group Bottom
%hook YTInlinePlayerBarContainerView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey]
        ? YSShareImage()
        : %orig;
}

%new(v@:@)
- (void)didPressYouShare:(id)arg {

    id overlayVC =
        [self.delegate valueForKey:@"_delegate"];

    YTPlayerViewController *vc =
        [overlayVC parentViewController];

    [vc didPressYouShare];
}

%end
%end

#pragma mark - Init

%ctor {

    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey : @"Copy Video URL",
        SelectorKey           : @"didPressYouShare:",
    });

    %init(Main);
    %init(Top);
    %init(Bottom);
}
