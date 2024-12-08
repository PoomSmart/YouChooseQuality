#import <YouTubeHeader/GCKNNetworkReachability.h>
#import <YouTubeHeader/MDXSessionManager.h>
#import <YouTubeHeader/MLAVAssetPlayer.h>
#import <YouTubeHeader/MLAVPlayer.h>
#import <YouTubeHeader/MLHAMPlayerItem.h>
#import <YouTubeHeader/MLQuickMenuVideoQualitySettingFormatConstraint.h>
#import <HBLog.h>
#import "Scenario.h"

extern BOOL IsEnabled();
extern int GetQuality(Scenario scenario);

BOOL isExternal = NO;

static Scenario GetScenario() {
    if ([NSProcessInfo processInfo].lowPowerModeEnabled) return LowPowerMode;
    BOOL isWifi = [[%c(GCKNNetworkReachability) sharedInstance] currentStatus] == 1;
    if (isWifi) return isExternal ? ExternalWifi : Wifi;
    return isExternal ? ExternalCellular : Cellular;
}

static NSString *getClosestQualityLabel(NSArray <MLFormat *> *formats) {
    Scenario scenario = GetScenario();
    int quality = GetQuality(scenario);
    HBLogDebug(@"YCQ - Quality: %d, Scenario: %d, External: %d", quality, scenario, isExternal);
    int targetResolution = quality / 100;
    int targetFPS = quality % 100;
    int minDiff = INT_MAX;
    NSString *closestQualityLabel = nil;
    for (MLFormat *format in formats) {
        int width = [format width];
        int height = [format height];
        int resolution = width > height ? height : width;
        int fps = [format FPS];
        int resolutionDiff = abs(resolution - targetResolution);
        int fpsDiff = abs(fps - targetFPS);
        int totalDiff = resolutionDiff + fpsDiff;
        HBLogDebug(@"YCQ - Available: %@, Resolution: %d, FPS: %d, Diff: %d", [format qualityLabel], resolution, fps, totalDiff);
        if (totalDiff < minDiff) {
            minDiff = totalDiff;
            closestQualityLabel = [format qualityLabel];
            HBLogDebug(@"YCQ - Selected: %@, Resolution: %d, FPS: %d", closestQualityLabel, resolution, fps);
        }
    }
    return closestQualityLabel;
}

static MLQuickMenuVideoQualitySettingFormatConstraint *getConstraint(NSString *qualityLabel) {
    MLQuickMenuVideoQualitySettingFormatConstraint *constraint;
    @try {
        constraint = [[%c(MLQuickMenuVideoQualitySettingFormatConstraint) alloc] initWithVideoQualitySetting:3 formatSelectionReason:2 qualityLabel:qualityLabel];
    } @catch (id ex) {
        constraint = [[%c(MLQuickMenuVideoQualitySettingFormatConstraint) alloc] initWithVideoQualitySetting:3 formatSelectionReason:2 qualityLabel:qualityLabel resolutionCap:0];
    }
    return constraint;
}

%hook MLHAMPlayerItem

- (void)onSelectableVideoFormats:(NSArray <MLFormat *> *)formats {
    %orig;
    if (!IsEnabled()) return;
    NSString *qualityLabel = getClosestQualityLabel(formats);
    self.videoFormatConstraint = getConstraint(qualityLabel);
}

%end

%hook MLAVPlayer

- (void)streamSelectorHasSelectableVideoFormats:(NSArray <MLFormat *> *)formats {
    %orig;
    if (!IsEnabled()) return;
    NSString *qualityLabel = getClosestQualityLabel(formats);
    self.videoFormatConstraint = getConstraint(qualityLabel);
}

%end

%hook MLAVAssetPlayer

// The changed value is not reliable but this method gets called whenever AirPlay session is started or stopped
- (void)playerExternalPlaybackActiveDidChange:(NSDictionary *)change {
    %orig;
    BOOL multipleScreens = [UIScreen screens].count > 1;
    if (isExternal != multipleScreens) {
        HBLogDebug(@"YCQ - Has Multiple Screens: %d", multipleScreens);
        isExternal = multipleScreens;
        MLAVPlayer *player = (MLAVPlayer *)self.delegate;
        NSString *qualityLabel = getClosestQualityLabel([player selectableVideoFormats]);
        player.videoFormatConstraint = getConstraint(qualityLabel);
    }
}

%end
