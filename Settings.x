#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <rootless.h>
#import "Scenario.h"

#define TweakName @"YouChooseQuality"
#define EnabledKey @"YCQ-Enabled"
#define QualityKey @"YCQ-Quality"

#define LOC(x) [tweakBundle localizedStringForKey:x value:nil table:nil]

static const NSInteger TweakSection = 'ycql';

@interface YTSettingsSectionItemManager (Tweak)
- (void)updateYouChooseQualitySectionWithEntry:(id)entry;
@end

int qualities[] = {
    216060,
    216050,
    216030,
    144060,
    144050,
    144030,
    108060,
    108050,
    108030,
    72060,
    72050,
    72030,
    48060,
    48050,
    48030,
    36060,
    36050,
    36030,
    24030,
    14430,
};

NSString *GetQualityKey(Scenario scenario) {
    return [NSString stringWithFormat:@"%@-%d", QualityKey, scenario];
}

NSString *GetQualityString(int quality) {
    return [NSString stringWithFormat:@"%dp%d", quality / 100, quality % 100];
}

BOOL IsEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:EnabledKey];
}

int GetQuality(Scenario scenario) {
    int quality = [[NSUserDefaults standardUserDefaults] integerForKey:GetQualityKey(scenario)];
    return quality ?: 108030;
}

void SetQuality(Scenario scenario, int quality) {
    [[NSUserDefaults standardUserDefaults] setInteger:quality forKey:GetQualityKey(scenario)];
}

int GetQualityIndex(Scenario scenario) {
    int quality = GetQuality(scenario);
    for (int i = 0; i < sizeof(qualities) / sizeof(qualities[0]); i++) {
        if (qualities[i] == quality)
            return i;
    }
    return 0;
}

NSBundle *TweakBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakName ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:ROOT_PATH_NS(@"/Library/Application Support/" TweakName ".bundle")];
    });
    return bundle;
}

%hook YTAppSettingsPresentationData

+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    NSMutableArray *mutableOrder = [order mutableCopy];
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound)
        [mutableOrder insertObject:@(TweakSection) atIndex:insertIndex + 1];
    return mutableOrder;
}

%end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYouChooseQualitySectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    NSBundle *tweakBundle = TweakBundle();
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    YTSettingsSectionItem *master = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"ENABLED")
        titleDescription:nil
        accessibilityIdentifier:nil
        switchOn:IsEnabled()
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:EnabledKey];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:master];

    for (Scenario scenario = 0; scenario < TotalScenarios; scenario++) {
        NSString *qualityLabelFormat = [NSString stringWithFormat:@"QUALITY_FOR_SCENARIO_%d", scenario];
        NSString *qualityLabel = LOC(qualityLabelFormat);
        YTSettingsSectionItem *quality = [YTSettingsSectionItemClass itemWithTitle:qualityLabel
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                int quality = GetQuality(scenario);
                return GetQualityString(quality);
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray array];
                for (int i = 0; i < sizeof(qualities) / sizeof(qualities[0]); i++) {
                    int quality = qualities[i];
                    [rows addObject:[YTSettingsSectionItemClass checkmarkItemWithTitle:GetQualityString(quality) titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        SetQuality(scenario, quality);
                        [settingsViewController reloadData];
                        return YES;
                    }]];
                }
                YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:qualityLabel pickerSectionTitle:nil rows:rows selectedItemIndex:GetQualityIndex(scenario) parentResponder:[self parentResponder]];
                [settingsViewController pushViewController:picker];
                return YES;
            }];
        [sectionItems addObject:quality];
    }

    NSString *titleDescription = LOC(@"TWEAK_DESC");
    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_SETTINGS_HD;
        [settingsViewController setSectionItems:sectionItems forCategory:TweakSection title:TweakName icon:icon titleDescription:titleDescription headerHidden:NO];
    } else
        [settingsViewController setSectionItems:sectionItems forCategory:TweakSection title:TweakName titleDescription:titleDescription headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == TweakSection) {
        [self updateYouChooseQualitySectionWithEntry:entry];
        return;
    }
    %orig;
}

%end
