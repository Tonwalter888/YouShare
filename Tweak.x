#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"

#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTActionSheetController.h>
#import <YouTubeHeader/YTActionSheetAction.h>
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/QTMIcon.h>

#define TweakKey @"YouShare"

#pragma mark - Required Forward Declarations

@interface YTActionSheetController (YouShare)
- (void)addAction:(YTActionSheetAction *)action;
@end

@interface YTPlayerViewController (YouShare)
- (void)didPressYouShare;
@end

#pragma mark - Helpers

static inline NSString *YSLocalized(NSString *key) {
    return NSLocalizedStringFromTableInBundle(
        key, nil,
        [NSBundle mainBundle], nil);
}

static UIImage *YSShareImage(void) {
    return [%c(QTMIcon)
        tintImage:[UIImage imageNamed:@"Share@3"]
        color:[%c(YTColor) white1]];
}

#pragma mark - Main Logic

%group Main
%hook YTPlayerViewController

%new
- (void)didPressYouShare {

    if (!self.currentVideoID || self.isPlayingAd)
        return;

    UIViewController *presenter =
        (UIViewController *)[self activeVideoPlayerOverlay];
    if (!presenter)
        return;

    NSInteger seconds =
        (NSInteger)floor(self.currentVideoMediaTime);

    NSString *baseURL =
        [NSString stringWithFormat:
            @"https://youtube.com/watch?v=%@", self.currentVideoID];

    NSString *timestampURL =
        [NSString stringWithFormat:
            @"%@&t=%lds", baseURL, (long)seconds];

    YTActionSheetController *sheet =
        [%c(YTActionSheetController) actionSheetController];

    if ([sheet respondsToSelector:@selector(addAction:)]) {

        YTActionSheetAction *copyURL =
            [%c(YTActionSheetAction)
                actionWithTitle:YSLocalized(@"COPY_URL")
                          style:0
                        handler:^(YTActionSheetAction *action) {
                UIPasteboard.generalPasteboard.string = baseURL;
            }];

        YTActionSheetAction *copyTimestamp =
            [%c(YTActionSheetAction)
                actionWithTitle:YSLocalized(@"COPY_URL_TIMESTAMP")
                          style:0
                        handler:^(YTActionSheetAction *action) {
                UIPasteboard.generalPasteboard.string = timestampURL;
            }];

        [sheet addAction:copyURL];
        [sheet addAction:copyTimestamp];
    }

    [sheet addCancelActionIfNeeded];
    [sheet presentFromViewController:presenter
                            animated:YES
                          completion:nil];
}

%end
%end

#pragma mark - Top Button

%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey]
        ? YSShareImage()
        : %orig;
}

%new(v@:@)
- (void)didPressYouShare:(id)arg {
    [(YTPlayerViewController *)self.playerViewController didPressYouShare];
}

%end
%end

#pragma mark - Bottom Button

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
        (YTPlayerViewController *)[overlayVC parentViewController];
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
