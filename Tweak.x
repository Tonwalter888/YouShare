#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"

#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTActionSheetController.h>
#import <YouTubeHeader/YTActionSheetAction.h>

#define TweakKey @"YouShare"

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

    if (!self.currentVideoID || self.isPlayingAd)
        return;

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
        (YTMainAppVideoPlayerOverlayViewController *)
        [self activeVideoPlayerOverlay];

    if (!overlay)
        return;

    // Native YouTube action sheet
    YTActionSheetController *sheet =
        [%c(YTActionSheetController) actionSheetController];

    // Copy URL
    [sheet addAction:
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"COPY_URL")
                      style:0
                    handler:^(__unused id action) {
        UIPasteboard.generalPasteboard.string = baseURL;
    }]];

    // Copy URL with timestamp
    [sheet addAction:
        [%c(YTActionSheetAction)
            actionWithTitle:YSLocalized(@"COPY_URL_TIMESTAMP")
                      style:0
                    handler:^(__unused id action) {
        UIPasteboard.generalPasteboard.string = timestampURL;
    }]];

    // Cancel (YouTube-style)
    [sheet addCancelActionIfNeeded];

    // Present using YouTube presenter (IMPORTANT)
    [sheet presentFromViewController:overlay
                            animated:YES
                          completion:nil];
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
    [self.playerViewController didPressYouShare];
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
    id overlayVC = [self.delegate valueForKey:@"_delegate"];
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
