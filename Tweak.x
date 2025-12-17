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

#pragma mark - YouTube private menu (forward declarations ONLY)

@interface YTActionSheetController : NSObject
- (void)addAction:(id)action;
@end

@interface YTActionSheetAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title
                         handler:(void (^)(id action))handler;
@end

@interface YTMainAppVideoPlayerOverlayViewController (YouShare)
- (void)presentActionSheet:(id)sheet;
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

#pragma mark - Main logic (YouTube native menu)

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

    YTMainAppVideoPlayerOverlayViewController *overlay =
        (YTMainAppVideoPlayerOverlayViewController *)
            [self activeVideoPlayerOverlay];

    if (!overlay) return;

    YTActionSheetController *sheet =
        [[%c(YTActionSheetController) alloc] init];

    [sheet addAction:
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"COPY_URL")
                    handler:^(__unused id a) {
        UIPasteboard.generalPasteboard.string = baseURL;
    }]];

    [sheet addAction:
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"COPY_URL_TIMESTAMP")
                    handler:^(__unused id a) {
        UIPasteboard.generalPasteboard.string = timestampURL;
    }]];

    [sheet addAction:
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"CANCEL")
                    handler:nil]];

    [overlay presentActionSheet:sheet];
}

%end
%end

#pragma mark - Top overlay button

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

#pragma mark - Bottom bar button

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
