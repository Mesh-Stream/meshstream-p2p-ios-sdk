#import <AppKit/AppKit.h>
#import <AVKit/AVKit.h>
#import <dispatch/dispatch.h>
#import <MeshStreamKit/MeshStreamKit.h>

static NSString *P2PFormatBytes(int64_t bytes) {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%lld B", bytes];
    }
    if (bytes < 1024LL * 1024LL) {
        return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024.0];
    }
    return [NSString stringWithFormat:@"%.2f MB", (double)bytes / (1024.0 * 1024.0)];
}

static NSString *P2PUnavailableReasonName(P2PUnavailableReason reason) {
    switch (reason) {
        case P2PUnavailableReasonNoPeers:
            return @"No peers";
        case P2PUnavailableReasonTrackerError:
            return @"Tracker error";
        case P2PUnavailableReasonAuthFailed:
            return @"Auth failed";
        case P2PUnavailableReasonAppDisabled:
            return @"App disabled";
        case P2PUnavailableReasonAppNotFound:
            return @"App not found";
        case P2PUnavailableReasonBundleDenied:
            return @"Bundle denied";
        case P2PUnavailableReasonUnsupported:
            return @"Unsupported";
        case P2PUnavailableReasonDisabled:
            return @"Disabled";
        default:
            return @"Unavailable";
    }
}

static NSString *P2PTrimmedText(NSTextField *field) {
    return [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@interface P2PDemoViewController : NSViewController <P2PEventListener>
@end

@interface P2PDemoViewController ()
@property(nonatomic, strong) AVPlayer *player;
@property(nonatomic, strong) dispatch_queue_t playerFeedbackQueue;
@property(nonatomic, strong) P2PClient *client;
@property(nonatomic, strong) PlaybackSession *session;
@property(nonatomic, strong) NSTimer *statsTimer;
@property(nonatomic, strong) NSTextField *streamField;
@property(nonatomic, strong) NSTextField *sdkKeyField;
@property(nonatomic, strong) NSButton *playButton;
@property(nonatomic, strong) NSButton *p2pButton;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSTextField *sdkEventLabel;
@property(nonatomic, strong) NSTextField *statsPeersLabel;
@property(nonatomic, strong) NSTextField *statsTrafficLabel;
@property(nonatomic, strong) NSTextField *statsOffloadLabel;
@property(nonatomic, strong) AVPlayerView *playerView;
@property(nonatomic, assign) BOOL p2pEnabled;
@end

@implementation P2PDemoViewController

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 980, 760)];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [NSColor colorWithCalibratedRed:245.0 / 255.0
                                                            green:247.0 / 255.0
                                                             blue:247.0 / 255.0
                                                            alpha:1.0].CGColor;
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.player = [[AVPlayer alloc] init];
    self.playerFeedbackQueue = dispatch_queue_create("io.meshstreamkit.demo.macos.player-feedback", DISPATCH_QUEUE_SERIAL);
    // Keep the sample's startup behavior aligned with iOS. This is an
    // AVPlayer choice in the demo, not part of the player-agnostic SDK URL
    // contract.
    self.player.automaticallyWaitsToMinimizeStalling = NO;
    self.p2pEnabled = YES;
    [self buildUI];
    [self refreshStats];
    self.statsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       target:self
                                                     selector:@selector(refreshStats)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)dealloc {
    [self.statsTimer invalidate];
    [self.session close];
    [self.player pause];
    [P2PSDK shutdown];
}

- (void)buildUI {
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.borderType = NSNoBorder;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.backgroundColor = NSColor.clearColor;

    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 920, 920)];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = content;
    [self.view addSubview:scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:24],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-24],
        [content.widthAnchor constraintEqualToAnchor:scrollView.contentView.widthAnchor]
    ]];

    NSStackView *stack = [NSStackView stackViewWithViews:@[]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
    ]];

    NSTextField *title = [self label:@"MeshStreamKit Native Interop" size:22 weight:NSFontWeightSemibold];
    [stack addArrangedSubview:title];

    self.streamField = [self input:@"HLS URL" value:@"https://test-streams.mux.dev/x36xhzz/url_2/193039199_mp4_h264_aac_ld_7.m3u8"];
    self.sdkKeyField = [self input:@"SDK Key" value:@""];
    [stack addArrangedSubview:self.streamField];
    [stack addArrangedSubview:self.sdkKeyField];

    NSStackView *buttons = [NSStackView stackViewWithViews:@[]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 12;
    buttons.distribution = NSStackViewDistributionFillEqually;
    self.playButton = [NSButton buttonWithTitle:@"Play" target:self action:@selector(createPlaybackSession)];
    self.p2pButton = [NSButton buttonWithTitle:@"Disable P2P" target:self action:@selector(toggleP2P)];
    [buttons addArrangedSubview:self.playButton];
    [buttons addArrangedSubview:self.p2pButton];
    [stack addArrangedSubview:buttons];

    self.statusLabel = [self label:@"Idle" size:15 weight:NSFontWeightRegular];
    self.sdkEventLabel = [self label:@"SDK event: idle" size:14 weight:NSFontWeightRegular];
    [stack addArrangedSubview:self.statusLabel];
    [stack addArrangedSubview:self.sdkEventLabel];

    self.playerView = [[AVPlayerView alloc] initWithFrame:NSZeroRect];
    self.playerView.player = self.player;
    self.playerView.controlsStyle = AVPlayerViewControlsStyleFloating;
    self.playerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playerView.heightAnchor constraintEqualToConstant:360].active = YES;
    [stack addArrangedSubview:self.playerView];

    NSTextField *statsTitle = [self label:@"Statistics" size:15 weight:NSFontWeightSemibold];
    [stack addArrangedSubview:statsTitle];

    self.statsPeersLabel = [self label:@"Peers 0" size:15 weight:NSFontWeightRegular];
    self.statsTrafficLabel = [self label:@"P2P down 0 B   HTTP down 0 B   P2P up 0 B" size:15 weight:NSFontWeightRegular];
    self.statsOffloadLabel = [self label:@"Offload 0%" size:15 weight:NSFontWeightRegular];
    [stack addArrangedSubview:self.statsPeersLabel];
    [stack addArrangedSubview:self.statsTrafficLabel];
    [stack addArrangedSubview:self.statsOffloadLabel];
}

- (NSTextField *)label:(NSString *)text size:(CGFloat)size weight:(NSFontWeight)weight {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = [NSColor colorWithCalibratedRed:21.0 / 255.0 green:25.0 / 255.0 blue:27.0 / 255.0 alpha:1.0];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (NSTextField *)input:(NSString *)placeholder value:(NSString *)value {
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.placeholderString = placeholder;
    field.stringValue = value ?: @"";
    field.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.controlSize = NSControlSizeRegular;
    field.bezeled = YES;
    field.bordered = YES;
    field.drawsBackground = YES;
    field.backgroundColor = NSColor.whiteColor;
    field.lineBreakMode = NSLineBreakByTruncatingTail;
    [field.heightAnchor constraintEqualToConstant:30].active = YES;
    return field;
}

- (void)createPlaybackSession {
    NSString *mediaUrl = P2PTrimmedText(self.streamField);
    NSString *sdkKey = P2PTrimmedText(self.sdkKeyField);

    if (mediaUrl.length == 0) {
        [self setStatus:@"HLS URL is empty" error:YES];
        return;
    }
    [self resetPlaybackForReplay];

    P2PConfig *config = [[P2PConfig alloc] initWithKey:sdkKey.length > 0 ? sdkKey : @"YOUR_SDK_KEY"];
    config.logLevel = P2PLogLevelInfo;

    self.playButton.enabled = NO;
    [self setStatus:@"Creating SDK client" error:NO];
    NSError *clientError = nil;
    self.client = [P2PSDK clientWithConfig:config error:&clientError];
    self.playButton.enabled = YES;
    NSURL *originURL = [NSURL URLWithString:mediaUrl];
    if (self.client == nil) {
        [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:originURL]];
        [self.player play];
        [self setStatus:@"SDK unavailable; playing from CDN" error:NO];
        [self setSdkEvent:clientError.localizedDescription ?: @"Client creation failed" error:YES];
        return;
    }
    [self.client addEventListener:self];
    NSError *playbackError = nil;
    self.session = [self.client createPlaybackSessionWithURL:originURL error:&playbackError];
    NSURL *playbackURL = self.session.playbackUrl ?: originURL;
    [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:playbackURL]];
    [self.player play];
    if (self.session == nil) {
        [self setStatus:@"P2P unavailable; playing from CDN" error:NO];
        [self setSdkEvent:playbackError.localizedDescription ?: @"Playback preparation failed" error:YES];
    } else {
        [self setStatus:@"Playing through SDK playbackUrl" error:NO];
        [self setSdkEvent:@"Playback prepared" error:NO];
        [self refreshStats];
    }
}

- (void)resetPlaybackForReplay {
    [self.session close];
    self.session = nil;
    self.client = nil;
    [self.player pause];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    [P2PSDK shutdown];

    self.p2pEnabled = YES;
    self.p2pButton.title = @"Disable P2P";
    self.statsPeersLabel.stringValue = @"Peers 0";
    self.statsTrafficLabel.stringValue = @"P2P down 0 B   HTTP down 0 B   P2P up 0 B";
    self.statsOffloadLabel.stringValue = @"Offload 0%";
    [self setSdkEvent:@"Resetting playback" error:NO];
}

- (void)toggleP2P {
    self.p2pEnabled = !self.p2pEnabled;
    [self.session setP2PEnabled:self.p2pEnabled];
    self.p2pButton.title = self.p2pEnabled ? @"Disable P2P" : @"Enable P2P";
    [self setSdkEvent:self.p2pEnabled ? @"P2P enabled" : @"P2P disabled" error:NO];
}

- (void)refreshStats {
    [self syncPlayerFeedback];
    P2PStats *stats = [self.session statistics];
    int64_t totalDown = stats.httpDownloaded + stats.p2pDownloaded;
    NSInteger offload = totalDown > 0 ? (NSInteger)lrint((double)stats.p2pDownloaded * 100.0 / (double)totalDown) : 0;
    self.statsPeersLabel.stringValue = [NSString stringWithFormat:@"Peers %ld", (long)stats.connectedPeers];
    self.statsTrafficLabel.stringValue = [NSString stringWithFormat:@"P2P down %@   HTTP down %@   P2P up %@",
                                         P2PFormatBytes(stats.p2pDownloaded),
                                         P2PFormatBytes(stats.httpDownloaded),
                                         P2PFormatBytes(stats.p2pUploaded)];
    self.statsOffloadLabel.stringValue = [NSString stringWithFormat:@"Offload %ld%%", (long)offload];
}

- (void)syncPlayerFeedback {
    PlaybackSession *session = self.session;
    AVPlayerItem *item = self.player.currentItem;
    if (session == nil || item == nil) {
        return;
    }

    CMTime currentTime = self.player.currentTime;
    if (!CMTIME_IS_NUMERIC(currentTime) || currentTime.timescale <= 0) {
        return;
    }
    int64_t currentPositionMs = (int64_t)llround(CMTimeGetSeconds(currentTime) * 1000.0);
    if (currentPositionMs < 0) {
        return;
    }

    CMTime bufferedEnd = kCMTimeInvalid;
    for (NSValue *value in item.loadedTimeRanges) {
        CMTimeRange range = value.CMTimeRangeValue;
        if (!CMTIME_IS_NUMERIC(range.start) || !CMTIME_IS_NUMERIC(range.duration)) {
            continue;
        }
        CMTime rangeEnd = CMTimeRangeGetEnd(range);
        if (CMTimeCompare(currentTime, range.start) >= 0 && CMTimeCompare(currentTime, rangeEnd) <= 0) {
            bufferedEnd = rangeEnd;
            break;
        }
    }
    int64_t bufferedDurationMs = 0;
    if (CMTIME_IS_NUMERIC(bufferedEnd) && CMTimeCompare(bufferedEnd, currentTime) > 0) {
        bufferedDurationMs = (int64_t)llround(CMTimeGetSeconds(CMTimeSubtract(bufferedEnd, currentTime)) * 1000.0);
    }

    dispatch_async(self.playerFeedbackQueue, ^{
        [session updateCurrentPositionMs:currentPositionMs];
        [session updateBufferedDurationMs:MAX(0, bufferedDurationMs)];
    });
}

- (void)setStatus:(NSString *)message error:(BOOL)isError {
    self.statusLabel.stringValue = message;
    self.statusLabel.textColor = isError ? [NSColor colorWithCalibratedRed:176.0 / 255.0 green:28.0 / 255.0 blue:28.0 / 255.0 alpha:1.0] : [NSColor colorWithCalibratedRed:35.0 / 255.0 green:45.0 / 255.0 blue:48.0 / 255.0 alpha:1.0];
}

- (void)setSdkEvent:(NSString *)message error:(BOOL)isError {
    self.sdkEventLabel.stringValue = [NSString stringWithFormat:@"SDK event: %@", message];
    self.sdkEventLabel.textColor = isError ? [NSColor colorWithCalibratedRed:176.0 / 255.0 green:28.0 / 255.0 blue:28.0 / 255.0 alpha:1.0] : [NSColor colorWithCalibratedRed:70.0 / 255.0 green:83.0 / 255.0 blue:88.0 / 255.0 alpha:1.0];
}

#pragma mark - P2PEventListener

- (void)onPlaybackPreparedWithPlaybackUrl:(NSURL *)playbackUrl {
    [self setSdkEvent:@"Playback prepared" error:NO];
}

- (void)onStatistics:(P2PStats *)stats {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshStats];
    });
}

- (void)onPeerCountChanged:(NSInteger)peerCount {
    [self setSdkEvent:[NSString stringWithFormat:@"Peers changed: %ld", (long)peerCount] error:NO];
}

- (void)onP2PReady {
    [self setSdkEvent:@"P2P ready" error:NO];
}

- (void)onP2PUnavailable:(P2PUnavailableReason)reason {
    [self setSdkEvent:[NSString stringWithFormat:@"P2P unavailable: %@", P2PUnavailableReasonName(reason)] error:YES];
}

- (void)onCdnFallbackWithBytes:(int64_t)bytes {
    [self setSdkEvent:[NSString stringWithFormat:@"CDN fallback: %@", P2PFormatBytes(bytes)] error:NO];
}

- (void)onTrackerErrorWithTotalErrors:(int64_t)totalErrors {
    [self setSdkEvent:[NSString stringWithFormat:@"Tracker errors: %lld", totalErrors] error:YES];
}

- (void)onPeerConnectErrorWithTotalErrors:(int64_t)totalErrors {
    [self setSdkEvent:[NSString stringWithFormat:@"Peer connect errors: %lld", totalErrors] error:YES];
}

@end

@interface P2PDemoAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSWindowController *windowController;
@end

@implementation P2PDemoAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1040, 860)
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"MeshStreamKit Native Interop";
    window.titleVisibility = NSWindowTitleVisible;
    window.releasedWhenClosed = NO;
    self.window = window;
    self.windowController = [[NSWindowController alloc] initWithWindow:window];
    self.window.contentViewController = [P2PDemoViewController new];
    [self.windowController showWindow:self];
    [self.window center];
    [NSApp activateIgnoringOtherApps:YES];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        P2PDemoAppDelegate *delegate = [P2PDemoAppDelegate new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
