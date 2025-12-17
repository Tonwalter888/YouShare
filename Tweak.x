#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"

#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>

#define TweakKey @"YouShare"

#pragma mark - Make Logos selector visible (IMPORTANT)

@interface YTPlayerViewController (YouShare)
- (void)didPressYouShare;
@end

#pragma mark - YouTube native menu (forward declarations ONLY)

@interface YTActionSheetAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title
                          style:(NSInteger)style
                        handler:(void (^)(YTActionSheetAction *action))handler;
@end

@interface YTActionSheetController : NSObject
+ (instancetype)actionSheetController;
- (void)addAction:(id)action;
- (void)addCancelActionIfNeeded;
- (void)presentFromViewController:(UIViewController *)viewController
                          animated:(BOOL)animated
                        completion:(void (^)(void))completion;
@end

#pragma mark - Bundle & localization

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

#pragma mark - Icon helper

static UIImage *YSShareImage(void) {
    return [%c(QTMIcon)
        tintImage:[UIImage imageNamed:@"Share@3"
                             inBundle:YouShareBundle()
        compatibleWithTraitCollection:nil]
        color:[%c(YTColor) white1]];
}

#pragma mark - MAIN LOGIC (YouTube native menu)

%group Main
%hook YTPlayerViewController

%new
- (void)didPressYouShare {

    if (!self.currentVideoID || self.isPlayingAd) return;

    NSInteger seconds =
        (NSInteger)floor(self.currentVideoMediaTime);

    NSString *baseURL =
        [NSString stringWithFormat:
            @"https://youtube.com/watch?v=%@", self.currentVideoID];

    NSString *timestampURL =
        [NSString stringWithFormat:
            @"%@&t=%lds", baseURL, (long)seconds];

    UIViewController *overlay =
        (UIViewController *)[self activeVideoPlayerOverlay];
    if (!overlay) return;

    YTActionSheetController *sheet =
        [%c(YTActionSheetController) actionSheetController];

    [sheet addAction:
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"COPY_URL")
                      style:0
                    handler:^(__unused YTActionSheetAction *a) {
        UIPasteboard.generalPasteboard.string = baseURL;
    }]];

    [sheet addAction:
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"COPY_URL_TIMESTAMP")
                      style:0
                    handler:^(__unused YTActionSheetAction *a) {
        UIPasteboard.generalPasteboard.string = timestampURL;
    }]];

    [sheet addCancelActionIfNeeded];

    [sheet presentFromViewController:overlay
                            animated:YES
                          completion:nil];
}

%end
%end

#pragma mark - TOP overlay button

%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey]
        ? YSShareImage()
        : %orig;
}

%new(v@:@)
- (void)didPressYouShare:(id)arg {
    [self.playerViewController didPressYouShare];
}

%end
%end

#pragma mark - BOTTOM bar button

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
        (YTPlayerViewController *)
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
