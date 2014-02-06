//
//  MinitorAppDelegate.m
//  Minitor
//
//  Created by Stephen Birarda on 1/29/2014.
//  Copyright (c) 2014 Stephen Birarda. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>

#import "MinitorAboutPreferencesViewController.h"
#import "MinitorAPIPreferencesWindowViewController.h"

#import "MinitorAppDelegate.h"

@interface MinitorAppDelegate(){
    NSString *actionProtocol;
}
@end

@implementation MinitorAppDelegate

static NSString *kActionProtocolUserStatus = @"getuserstatus";
static NSString *kActionProtocolDashboardData = @"getdashboarddata";

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    actionProtocol = kActionProtocolDashboardData;
    
    [self setupStatusBar];
    
    [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(refreshStats) userInfo:nil repeats:YES];
    [self refreshStats];
}

- (void)setupStatusBar {
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self __setStatusText:@"Loading..."];
    _statusItem.highlightMode = YES;
    
    _statusItem.menu = [self defaultMenu];
}

- (NSMenu *)defaultMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    
    if ([actionProtocol isEqualToString:@"getuserstatus"]){
        [menu addItemWithTitle:@"Share Rate: -" action:nil keyEquivalent:@""];
        [menu addItemWithTitle:@"Valid:- Invalid:-" action:nil keyEquivalent:@""];
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Preferences..." action:@selector(openSettings:) keyEquivalent:@""];
        [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    }
    else if ([actionProtocol isEqualToString:@"getdashboarddata"]){
        [menu addItemWithTitle:@"Block: -" action:nil keyEquivalent:@""];
        [menu addItemWithTitle:@"Payout: -" action:nil keyEquivalent:@""];
        [menu addItemWithTitle:@"Progress: -" action:nil keyEquivalent:@""];
        [menu addItemWithTitle:@"Difficulty: -" action:nil keyEquivalent:@""];
        [menu addItemWithTitle:@"Next Difficulty: -" action:nil keyEquivalent:@""];
        [menu addItemWithTitle:@"Valid:- Invalid:-" action:nil keyEquivalent:@""];
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Preferences..." action:@selector(openSettings:) keyEquivalent:@""];
        [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    }
    
    return menu;
}

#pragma mark - Actions

- (IBAction)openSettings:(id)sender {
    [self.settingsController showWindow:nil];
}

- (MASPreferencesWindowController *)settingsController {
    if (!_settingsController) {
        NSViewController *apiViewController = [[MinitorAPIPreferencesWindowViewController alloc] init];
        NSViewController *aboutViewController = [[MinitorAboutPreferencesViewController alloc] init];
        NSArray *controllers = @[apiViewController, aboutViewController];
        
        NSString *title = NSLocalizedString(@"Preferences", @"Common title for Preferences window");
        _settingsController = [[MASPreferencesWindowController alloc] initWithViewControllers:controllers title:title];
    }
    return _settingsController;
}

- (void)refreshStats {
    
    // make sure we have a URL, API key, and user ID
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableString *apiURL = [[defaults valueForKey:@"api-url"] mutableCopy];
    NSString *apiKey = [defaults valueForKey:@"api-key"];
    NSString *userID = [defaults valueForKey:@"api-user-id"];
    
    if (apiURL && apiKey && userID) {
        NSDictionary *params = @{ @"page": @"api",
                                  @"action": actionProtocol,
                                  @"api_key": apiKey,
                                  @"id": userID};
        
        if ([apiURL rangeOfString:@"index.php"].length > 0) {
            if (![apiURL hasSuffix:@"/"]) {
                [apiURL appendString:@"/"];
            }
            
            [apiURL appendString:@"index.php"];
        }
        
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];
        
        NSMutableSet *contentTypes = [manager.responseSerializer.acceptableContentTypes mutableCopy];
        [contentTypes addObject:@"text/html"];
        manager.responseSerializer.acceptableContentTypes = contentTypes;
        
        [manager GET:apiURL parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSDictionary *jsonResponse = (NSDictionary *)responseObject;
            
            if ([actionProtocol isEqualToString:@"getuserstatus"]){
                NSDictionary *mainData = [jsonResponse valueForKeyPath:@"getuserstatus.data"];
                
                if (mainData) {
                    [self __setStatusText:[NSString stringWithFormat:@"%1.0lf KH/s", [[mainData valueForKey:@"hashrate"] doubleValue]]];
                    
                    [[_statusItem.menu itemAtIndex:0] setTitle:[NSString stringWithFormat:@"Share Rate: %@", [mainData valueForKeyPath:@"sharerate"]]];
                    [[_statusItem.menu itemAtIndex:1] setTitle:[NSString stringWithFormat:@"Valid: %@, Invalid: %@", [mainData valueForKeyPath:@"shares.valid"], [mainData valueForKeyPath:@"shares.invalid"]]];
                }
                else {
                    actionProtocol = kActionProtocolDashboardData;
                    [self setupStatusBar];
                    [self refreshStats];
                }
            }
            else if ([actionProtocol isEqualToString:@"getdashboarddata"]) {
                NSDictionary *personalData = [jsonResponse valueForKeyPath:@"getdashboarddata.data.personal"];
                NSDictionary *poolData = [jsonResponse valueForKeyPath:@"getdashboarddata.data.pool"];
                NSDictionary *networkData = [jsonResponse valueForKeyPath:@"getdashboarddata.data.network"];
                
                if (personalData) {
                    NSString *currencyString = [jsonResponse valueForKeyPath:@"getdashboarddata.data.pool.info.currency"];
                    [self __setStatusText:[NSString stringWithFormat:@"%1.0lf KH/s", [[personalData valueForKey:@"hashrate"] doubleValue]]];
                    
                    [[_statusItem.menu itemAtIndex:0] setTitle:[NSString stringWithFormat:@"Block: %@", [networkData valueForKeyPath:@"block"]]];
                    [[_statusItem.menu itemAtIndex:1] setTitle:[NSString stringWithFormat:@"Payout: %1.1lf%@", [[personalData valueForKeyPath:@"estimates.payout"] floatValue], (currencyString ? [NSString stringWithFormat:@" %@", currencyString] : nil)]];
                    [[_statusItem.menu itemAtIndex:2] setTitle:[NSString stringWithFormat:@"Progress: %1.1lf%%", [[poolData valueForKeyPath:@"shares.progress"] floatValue]]];
                    [[_statusItem.menu itemAtIndex:3] setTitle:[NSString stringWithFormat:@"Difficulty: %1.0lf", [[networkData valueForKeyPath:@"difficulty"] floatValue]]];
                    [[_statusItem.menu itemAtIndex:4] setTitle:[NSString stringWithFormat:@"Next Difficulty: %1.0lf", [[networkData valueForKeyPath:@"nextdifficulty"] floatValue]]];
                    [[_statusItem.menu itemAtIndex:5] setTitle:[NSString stringWithFormat:@"Valid: %@, Invalid: %@", [personalData valueForKeyPath:@"shares.valid"], [personalData valueForKeyPath:@"shares.invalid"]]];
                }
                else {
                    actionProtocol = kActionProtocolUserStatus;
                    [self setupStatusBar];
                    [self refreshStats];
                }
            }
            
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Error: %@", error);
        }];
    }
}

- (void)__setStatusText:(NSString *)text{
    NSDictionary *fontAttributes = @{
                                     NSFontAttributeName : [NSFont systemFontOfSize:13]
                       };
    
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:text attributes:fontAttributes];
    [_statusItem setAttributedTitle:attrString];
}

#pragma mark -

NSString *const kFocusedAdvancedControlIndex = @"FocusedAdvancedControlIndex";

- (NSInteger)focusedAdvancedControlIndex
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:kFocusedAdvancedControlIndex];
}

- (void)setFocusedAdvancedControlIndex:(NSInteger)focusedAdvancedControlIndex
{
    [[NSUserDefaults standardUserDefaults] setInteger:focusedAdvancedControlIndex forKey:kFocusedAdvancedControlIndex];
}

@end
