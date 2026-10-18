#import "P2PDemoViewController.h"
#import <AVKit/AVKit.h>
#import <MeshStreamKit/MeshStreamKit.h>

static void *P2PPlayerItemStatusContext = &P2PPlayerItemStatusContext;
static void *P2PPlayerItemPresentationSizeContext = &P2PPlayerItemPresentationSizeContext;
static void *P2PPlayerItemLikelyToKeepUpContext = &P2PPlayerItemLikelyToKeepUpContext;
static void *P2PPlayerTimeControlContext = &P2PPlayerTimeControlContext;
static void *P2PPlayerReadyForDisplayContext = &P2PPlayerReadyForDisplayContext;

// Observe explicit public pause commands separately from AVFoundation's
// asynchronous SetRateFailed/system pauses. This is Demo-only integration,
// works on iOS 13+, and does not swizzle or constrain SDK customers' players.
@interface P2PDemoPlayer : AVPlayer
@property(nonatomic, copy) void (^pauseCommandHandler)(void);
@end

@implementation P2PDemoPlayer
- (void)pause {
    if (self.pauseCommandHandler) self.pauseCommandHandler();
    [super pause];
}
- (void)setRate:(float)rate {
    if (rate == 0.0 && self.pauseCommandHandler) self.pauseCommandHandler();
    [super setRate:rate];
}
@end

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

@interface P2PDemoViewController () <P2PEventListener>
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIStackView *stackView;
@property(nonatomic, strong) AVPlayer *player;
@property(nonatomic, strong) AVPlayerViewController *playerController;
@property(nonatomic, strong) dispatch_queue_t playbackWorkQueue;
@property(nonatomic, strong) dispatch_queue_t playerPreparationQueue;
@property(nonatomic, assign) NSUInteger playbackGeneration;
@property(nonatomic, assign) BOOL applicationInactive;
@property(nonatomic, assign) BOOL audioInterrupted;
@property(nonatomic, assign) BOOL interruptionBlocksStartup;
@property(nonatomic, assign) BOOL initialPlayerStartPending;
@property(nonatomic, strong) P2PClient *client;
@property(nonatomic, copy) NSString *clientSdkKey;
@property(nonatomic, strong) PlaybackSession *session;
@property(nonatomic, strong) NSTimer *statsTimer;
@property(nonatomic, strong) UITextField *streamField;
@property(nonatomic, strong) UITextField *sdkKeyField;
@property(nonatomic, strong) UIButton *playButton;
@property(nonatomic, strong) UIButton *p2pButton;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UILabel *sdkEventLabel;
@property(nonatomic, strong) UILabel *playbackUrlLabel;
@property(nonatomic, strong) UILabel *statsPeersLabel;
@property(nonatomic, strong) UILabel *statsTrafficLabel;
@property(nonatomic, strong) UILabel *statsOffloadLabel;
@property(nonatomic, strong, nullable) P2PStats *latestStats;
@property(nonatomic, strong) AVPlayerItem *observedItem;
@property(nonatomic, assign) BOOL p2pEnabled;
@property(nonatomic, assign) BOOL didAutoStartPlayback;
@property(nonatomic, assign) BOOL pendingPlayerStart;
@property(nonatomic, assign) BOOL automaticStartActive;
@property(nonatomic, assign) BOOL hasObservedPlaybackState;
@property(nonatomic, assign) BOOL userPausedPlayback;
@property(nonatomic, assign) BOOL applyingPlaybackCommand;
@property(nonatomic, assign) BOOL resettingPlayback;
@property(nonatomic, assign) BOOL didLogFirstFrame;
@property(nonatomic, assign) BOOL didLogVideoMetadata;
@property(nonatomic, assign) CFAbsoluteTime playbackStartedAt;
@property(nonatomic, assign) int64_t lastLoggedHttpDownloaded;
@property(nonatomic, assign) int64_t lastLoggedP2pDownloaded;
@property(nonatomic, assign) int64_t lastLoggedP2pUploaded;
@end

@implementation P2PDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:245.0 / 255.0 green:247.0 / 255.0 blue:247.0 / 255.0 alpha:1.0];
    P2PDemoPlayer *player = [[P2PDemoPlayer alloc] init];
    self.player = player;
    __weak typeof(self) weakSelf = self;
    player.pauseCommandHandler = ^{
        [weakSelf handleExplicitPlayerPause];
    };
    self.playbackWorkQueue = dispatch_queue_create("io.meshstreamkit.demo.ios.playback-work", DISPATCH_QUEUE_SERIAL);
    self.playerPreparationQueue = dispatch_queue_create("io.meshstreamkit.demo.ios.player-prepare", DISPATCH_QUEUE_CONCURRENT);
    self.applicationInactive = UIApplication.sharedApplication.applicationState != UIApplicationStateActive;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(applicationWillResignActive:)
                   name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(applicationDidBecomeActive:)
                   name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(audioSessionInterrupted:)
                   name:AVAudioSessionInterruptionNotification object:nil];
    // The SDK exposes a URL and must remain player-agnostic. For this AVPlayer
    // demo, start rendering as soon as the item can decode instead of waiting
    // for AVPlayer's larger anti-stall startup buffer.
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

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.didAutoStartPlayback) {
        return;
    }
    NSString *autoStart = NSProcessInfo.processInfo.environment[@"MESHSTREAM_AUTOCREATE_PLAYBACK_SESSION"];
    if (autoStart.length == 0 || [autoStart isEqualToString:@"0"]) {
        return;
    }
    self.didAutoStartPlayback = YES;
    NSLog(@"[MeshStreamKit] autoplay requested");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self createPlaybackSession];
    });
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self.statsTimer invalidate];
    [self stopObservingPlayerItem];
    [self.player removeObserver:self forKeyPath:@"timeControlStatus"];
    [self.playerController removeObserver:self forKeyPath:@"readyForDisplay"];
    [self.session close];
    [self.player pause];
    [P2PSDK shutdown];
}

- (void)buildUI {
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.directionalLockEnabled = YES;
    [self.view addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    UIView *content = [[UIView alloc] initWithFrame:CGRectZero];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:content];
    // Keep the content readable on iPad and landscape while allowing the
    // same layout to shrink naturally on iPhone/compact split view.  The
    // width equality is intentionally slightly lower priority than the
    // max-width constraint: on narrow devices it follows the viewport, and
    // on wide devices the centered 760pt column wins without constraint
    // breaking or horizontal clipping.
    UIView *layoutContainer = [UIView new];
    layoutContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:layoutContainer];
    NSLayoutConstraint *viewportWidth = [layoutContainer.widthAnchor constraintEqualToAnchor:content.widthAnchor constant:-40.0];
    viewportWidth.priority = UILayoutPriorityRequired - 1.0;
    [NSLayoutConstraint activateConstraints:@[
        [layoutContainer.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [layoutContainer.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [layoutContainer.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
        viewportWidth,
        [layoutContainer.widthAnchor constraintLessThanOrEqualToConstant:760.0],
        [layoutContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor constant:20],
        [layoutContainer.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor constant:-20]
    ]];

    self.stackView = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.spacing = 16;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [layoutContainer addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:layoutContainer.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:layoutContainer.trailingAnchor],
        [self.stackView.topAnchor constraintEqualToAnchor:layoutContainer.topAnchor],
        [self.stackView.bottomAnchor constraintEqualToAnchor:layoutContainer.bottomAnchor]
    ]];

    UIStackView *header = [self verticalStackWithSpacing:5];
    [header addArrangedSubview:[self titleLabel:@"MeshStreamKit"]];
    UILabel *subtitle = [self label:@"Native playback and P2P diagnostics" size:14 weight:UIFontWeightRegular];
    subtitle.textColor = UIColor.secondaryLabelColor;
    [header addArrangedSubview:subtitle];
    [self.stackView addArrangedSubview:header];

    UIView *setupCard = [self cardView];
    UIStackView *setupContent = [self verticalStackWithSpacing:12];
    [setupCard addSubview:setupContent];
    [NSLayoutConstraint activateConstraints:@[
        [setupContent.leadingAnchor constraintEqualToAnchor:setupCard.layoutMarginsGuide.leadingAnchor],
        [setupContent.trailingAnchor constraintEqualToAnchor:setupCard.layoutMarginsGuide.trailingAnchor],
        [setupContent.topAnchor constraintEqualToAnchor:setupCard.layoutMarginsGuide.topAnchor],
        [setupContent.bottomAnchor constraintEqualToAnchor:setupCard.layoutMarginsGuide.bottomAnchor]
    ]];
    [setupContent addArrangedSubview:[self sectionTitle:@"Playback setup"]];
    self.streamField = [self inputField:@"Media URL" value:@"https://test-streams.mux.dev/x36xhzz/url_2/193039199_mp4_h264_aac_ld_7.m3u8"];
    self.sdkKeyField = [self inputField:@"SDK Key" value:[self defaultSdkKey]];
    self.sdkKeyField.keyboardType = UIKeyboardTypeASCIICapable;
    [setupContent addArrangedSubview:[self inputGroupWithTitle:@"Media URL" field:self.streamField]];
    [setupContent addArrangedSubview:[self inputGroupWithTitle:@"SDK key" field:self.sdkKeyField]];
    [self.stackView addArrangedSubview:setupCard];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.spacing = 12;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    self.playButton = [self actionButton:@"Play" action:@selector(createPlaybackSession)];
    self.p2pButton = [self actionButton:@"Disable P2P" action:@selector(toggleP2P)];
    [buttons addArrangedSubview:self.playButton];
    [buttons addArrangedSubview:self.p2pButton];
    UIView *actionsCard = [self cardView];
    [actionsCard addSubview:buttons];
    [NSLayoutConstraint activateConstraints:@[
        [buttons.leadingAnchor constraintEqualToAnchor:actionsCard.layoutMarginsGuide.leadingAnchor],
        [buttons.trailingAnchor constraintEqualToAnchor:actionsCard.layoutMarginsGuide.trailingAnchor],
        [buttons.topAnchor constraintEqualToAnchor:actionsCard.layoutMarginsGuide.topAnchor],
        [buttons.bottomAnchor constraintEqualToAnchor:actionsCard.layoutMarginsGuide.bottomAnchor]
    ]];
    [self.stackView addArrangedSubview:actionsCard];

    self.statusLabel = [self label:@"Idle" size:14 weight:UIFontWeightMedium];
    self.sdkEventLabel = [self label:@"SDK event: idle" size:13 weight:UIFontWeightRegular];
    self.playbackUrlLabel = [self label:@"Playback URL: -" size:11 weight:UIFontWeightRegular];
    self.statusLabel.backgroundColor = UIColor.tertiarySystemFillColor;
    self.statusLabel.layer.cornerRadius = 9.0;
    self.statusLabel.layer.masksToBounds = YES;
    self.statusLabel.layoutMargins = UIEdgeInsetsMake(7, 10, 7, 10);
    UIView *statusCard = [self cardView];
    UIStackView *statusContent = [self verticalStackWithSpacing:10];
    [statusCard addSubview:statusContent];
    [NSLayoutConstraint activateConstraints:@[
        [statusContent.leadingAnchor constraintEqualToAnchor:statusCard.layoutMarginsGuide.leadingAnchor],
        [statusContent.trailingAnchor constraintEqualToAnchor:statusCard.layoutMarginsGuide.trailingAnchor],
        [statusContent.topAnchor constraintEqualToAnchor:statusCard.layoutMarginsGuide.topAnchor],
        [statusContent.bottomAnchor constraintEqualToAnchor:statusCard.layoutMarginsGuide.bottomAnchor]
    ]];
    [statusContent addArrangedSubview:[self sectionTitle:@"Playback status"]];
    [statusContent addArrangedSubview:self.statusLabel];
    [statusContent addArrangedSubview:self.sdkEventLabel];
    [statusContent addArrangedSubview:self.playbackUrlLabel];
    [self.stackView addArrangedSubview:statusCard];

    self.playerController = [AVPlayerViewController new];
    self.playerController.player = self.player;
    self.playerController.showsPlaybackControls = YES;
    [self.playerController addObserver:self
                           forKeyPath:@"readyForDisplay"
                              options:NSKeyValueObservingOptionNew
                              context:P2PPlayerReadyForDisplayContext];
    [self.player addObserver:self
                  forKeyPath:@"timeControlStatus"
                     options:NSKeyValueObservingOptionNew
                     context:P2PPlayerTimeControlContext];
    [self addChildViewController:self.playerController];
    UIView *playerContainer = [[UIView alloc] initWithFrame:CGRectZero];
    playerContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.playerController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [playerContainer addSubview:self.playerController.view];
    [NSLayoutConstraint activateConstraints:@[
        [self.playerController.view.leadingAnchor constraintEqualToAnchor:playerContainer.leadingAnchor],
        [self.playerController.view.trailingAnchor constraintEqualToAnchor:playerContainer.trailingAnchor],
        [self.playerController.view.topAnchor constraintEqualToAnchor:playerContainer.topAnchor],
        [self.playerController.view.bottomAnchor constraintEqualToAnchor:playerContainer.bottomAnchor]
    ]];
    [playerContainer.heightAnchor constraintEqualToAnchor:playerContainer.widthAnchor multiplier:9.0 / 16.0].active = YES;
    playerContainer.backgroundColor = UIColor.blackColor;
    playerContainer.layer.cornerRadius = 16.0;
    playerContainer.clipsToBounds = YES;
    [self.playerController didMoveToParentViewController:self];
    [self.stackView addArrangedSubview:playerContainer];

    self.statsPeersLabel = [self label:@"Peers 0" size:14 weight:UIFontWeightRegular];
    self.statsTrafficLabel = [self label:@"P2P down 0 B\nHTTP down 0 B\nP2P up 0 B" size:14 weight:UIFontWeightRegular];
    self.statsOffloadLabel = [self label:@"Offload 0%" size:14 weight:UIFontWeightRegular];
    UIView *statsCard = [self cardView];
    UIStackView *statsContent = [self verticalStackWithSpacing:10];
    [statsCard addSubview:statsContent];
    [NSLayoutConstraint activateConstraints:@[
        [statsContent.leadingAnchor constraintEqualToAnchor:statsCard.layoutMarginsGuide.leadingAnchor],
        [statsContent.trailingAnchor constraintEqualToAnchor:statsCard.layoutMarginsGuide.trailingAnchor],
        [statsContent.topAnchor constraintEqualToAnchor:statsCard.layoutMarginsGuide.topAnchor],
        [statsContent.bottomAnchor constraintEqualToAnchor:statsCard.layoutMarginsGuide.bottomAnchor]
    ]];
    [statsContent addArrangedSubview:[self sectionTitle:@"P2P statistics"]];
    [statsContent addArrangedSubview:self.statsPeersLabel];
    [statsContent addArrangedSubview:self.statsTrafficLabel];
    [statsContent addArrangedSubview:self.statsOffloadLabel];
    [self.stackView addArrangedSubview:statsCard];
}

- (UILabel *)titleLabel:(NSString *)text {
    UILabel *label = [self label:text size:30 weight:UIFontWeightBold];
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (UILabel *)sectionTitle:(NSString *)text {
    UILabel *label = [self label:text size:17 weight:UIFontWeightSemibold];
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (UIStackView *)verticalStackWithSpacing:(CGFloat)spacing {
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    return stack;
}

- (UIView *)cardView {
    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 18.0;
    card.layoutMargins = UIEdgeInsetsMake(16, 16, 16, 16);
    return card;
}

- (UIStackView *)inputGroupWithTitle:(NSString *)title field:(UITextField *)field {
    UILabel *label = [self label:title size:12 weight:UIFontWeightMedium];
    label.textColor = UIColor.secondaryLabelColor;
    UIStackView *group = [[UIStackView alloc] initWithArrangedSubviews:@[label, field]];
    group.axis = UILayoutConstraintAxisVertical;
    group.alignment = UIStackViewAlignmentFill;
    group.spacing = 4;
    group.translatesAutoresizingMaskIntoConstraints = NO;
    return group;
}

- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = UIColor.labelColor;
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UITextField *)inputField:(NSString *)placeholder value:(NSString *)value {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.text = value ?: @"";
    field.borderStyle = UITextBorderStyleNone;
    field.backgroundColor = UIColor.tertiarySystemFillColor;
    field.layer.cornerRadius = 10.0;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 11, 1)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 11, 1)];
    field.rightViewMode = UITextFieldViewModeAlways;
    field.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    field.adjustsFontForContentSizeCategory = YES;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.keyboardType = UIKeyboardTypeURL;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [field.heightAnchor constraintEqualToConstant:40].active = YES;
    return field;
}

- (UIButton *)actionButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.backgroundColor = UIColor.systemBlueColor;
    button.layer.cornerRadius = 12.0;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:46].active = YES;
    return button;
}

- (NSString *)defaultSdkKey {
    NSString *sdkKey = NSProcessInfo.processInfo.environment[@"MESHSTREAM_SDK_KEY"];
    if (sdkKey.length == 0) {
        sdkKey = [NSBundle.mainBundle objectForInfoDictionaryKey:@"MeshStreamSDKKey"];
    }
    return sdkKey.length > 0 ? sdkKey : @"";
}

- (void)createPlaybackSession {
    self.playbackStartedAt = CFAbsoluteTimeGetCurrent();
    self.didLogFirstFrame = NO;
    self.didLogVideoMetadata = NO;
    self.userPausedPlayback = NO;
    self.interruptionBlocksStartup = NO;
    self.lastLoggedHttpDownloaded = 0;
    self.lastLoggedP2pDownloaded = 0;
    self.lastLoggedP2pUploaded = 0;
    NSLog(@"[MeshStreamKit] play tapped");
    NSString *mediaUrl = [self.streamField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *sdkKey = [self.sdkKeyField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    if (mediaUrl.length == 0) {
        [self setStatus:@"HLS URL is empty" error:YES];
        return;
    }
    NSLog(@"[MeshStreamKit] reset begin elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
    [self resetPlaybackForReplay];
    NSLog(@"[MeshStreamKit] reset end elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);

    NSString *bypassProxy = NSProcessInfo.processInfo.environment[@"MESHSTREAM_BYPASS_PROXY"];
    if ([bypassProxy isEqualToString:@"1"] || [bypassProxy.lowercaseString isEqualToString:@"true"]) {
        [self playOriginURL:mediaUrl];
        return;
    }

    NSString *resolvedSdkKey = sdkKey.length > 0 ? sdkKey : @"YOUR_SDK_KEY";
    BOOL sdkKeyChanged = self.client != nil && ![self.clientSdkKey isEqualToString:resolvedSdkKey];
    if (sdkKeyChanged) {
        [self.client removeEventListener:self];
        [P2PSDK shutdown];
        self.client = nil;
        self.clientSdkKey = nil;
    }
    if (self.client == nil || ![self.clientSdkKey isEqualToString:resolvedSdkKey]) {
        // Keep one native client/runtime alive across replay taps. Rebuilding
        // it for every tap can race Tokio task shutdown and briefly stall the
        // main thread while the old proxy is still being torn down.
        P2PConfig *config = [[P2PConfig alloc] initWithKey:resolvedSdkKey];
        config.logLevel = P2PLogLevelInfo;

        NSError *clientError = nil;
        self.client = [P2PSDK clientWithConfig:config error:&clientError];
        self.clientSdkKey = self.client == nil ? nil : resolvedSdkKey;
        if (self.client == nil) {
            NSLog(@"[MeshStreamKit] sdk client create failed elapsed=%.0fms error=%@",
                  [self elapsedSincePlaybackStartMs], clientError.localizedDescription ?: @"unknown");
            [self setStatus:[NSString stringWithFormat:@"SDK client create failed: %@", clientError.localizedDescription ?: @"unknown"] error:YES];
            [self playOriginURL:mediaUrl];
            return;
        }
        [self.client addEventListener:self];
    }
    NSLog(@"[MeshStreamKit] sdk client created elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
    NSError *playbackError = nil;
    self.session = [self.client createPlaybackSessionWithURL:[NSURL URLWithString:mediaUrl] error:&playbackError];
    NSLog(@"[MeshStreamKit] playback prepared elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
    if (self.session == nil) {
        [self setStatus:[NSString stringWithFormat:@"Playback prep failed: %@", playbackError.localizedDescription ?: @"unknown"] error:YES];
        [self playOriginURL:mediaUrl];
        return;
    }
    self.playbackUrlLabel.text = [NSString stringWithFormat:@"Playback URL: %@", self.session.playbackUrl.absoluteString];
    NSLog(@"[MeshStreamKit] playbackUrl: %@", self.session.playbackUrl.absoluteString);
    [self preparePlayerItemWithURL:self.session.playbackUrl cdnFallback:NO];
    [self setSdkEvent:@"Playback prepared" error:NO];
    [self refreshStats];
}

- (void)preparePlayerItemWithURL:(NSURL *)url cdnFallback:(BOOL)cdnFallback {
    NSUInteger generation = self.playbackGeneration;
    CFAbsoluteTime playbackStartedAt = self.playbackStartedAt;
    CFAbsoluteTime enqueuedAt = CFAbsoluteTimeGetCurrent();
    [self setStatus:@"Preparing AVPlayer item" error:NO];
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.playerPreparationQueue, ^{
        @autoreleasepool {
            CFAbsoluteTime creationStartedAt = CFAbsoluteTimeGetCurrent();
            NSLog(@"[MeshStreamKit] player item create begin generation=%lu main=%@ queue_wait=%.0fms elapsed=%.0fms",
                  (unsigned long)generation, NSThread.isMainThread ? @"yes" : @"no",
                  (creationStartedAt - enqueuedAt) * 1000.0,
                  (creationStartedAt - playbackStartedAt) * 1000.0);
            AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
            NSLog(@"[MeshStreamKit] player item created generation=%lu duration=%.0fms elapsed=%.0fms",
                  (unsigned long)generation, (CFAbsoluteTimeGetCurrent() - creationStartedAt) * 1000.0,
                  (CFAbsoluteTimeGetCurrent() - playbackStartedAt) * 1000.0);
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (self == nil || generation != self.playbackGeneration) {
                    NSLog(@"[MeshStreamKit] obsolete player item discarded generation=%lu", (unsigned long)generation);
                    return;
                }
                [self installPlayerItem:item cdnFallback:cdnFallback];
            });
        }
    });
}

- (void)installPlayerItem:(AVPlayerItem *)item cdnFallback:(BOOL)cdnFallback {
    [self observePlayerItem:item];
    NSLog(@"[MeshStreamKit] player item observed elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
    NSLog(@"[MeshStreamKit] assigning player controller elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
    self.playerController.player = self.player;
    NSLog(@"[MeshStreamKit] player controller assigned elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
    // Start playback as soon as the proxy URL is installed. Waiting for
    // AVPlayerItemStatusReadyToPlay here adds a second readiness gate on top
    // of AVPlayer's own buffering and can delay the first frame substantially.
    self.pendingPlayerStart = YES;
    self.initialPlayerStartPending = YES;
    self.automaticStartActive = YES;
    self.hasObservedPlaybackState = NO;
    // Keep startup eager, then let AVPlayer recover automatically when a
    // later HLS segment has a CDN-side delivery gap.
    self.player.automaticallyWaitsToMinimizeStalling = NO;
    NSLog(@"[MeshStreamKit] replacing player item begin elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
    [self.player replaceCurrentItemWithPlayerItem:item];
    NSLog(@"[MeshStreamKit] replacing player item end elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
    [self startInitialPlayerPlaybackIfAllowed];
    [self setStatus:cdnFallback ? @"P2P unavailable; playing from CDN" : @"Waiting for AVPlayer to request SDK playbackUrl" error:NO];
}

- (void)resetPlaybackForReplay {
    // Item construction can outlive a replay tap. Only its matching Play
    // generation may attach an item or issue a playback command.
    self.playbackGeneration += 1;
    CFAbsoluteTime resetStartedAt = CFAbsoluteTimeGetCurrent();
    self.resettingPlayback = YES;
    PlaybackSession *oldSession = self.session;
    self.session = nil;
    if (oldSession != nil) {
        // PlaybackSession.close is non-blocking in the SDK. It detaches the
        // native session immediately and performs Rust teardown in the SDK's
        // own background queue, so callers can safely invoke it from UIKit.
        [oldSession close];
    }
    NSLog(@"[MeshStreamKit] reset session close elapsed=%.0fms", (CFAbsoluteTimeGetCurrent() - resetStartedAt) * 1000.0);
    self.applyingPlaybackCommand = YES;
    [self.player pause];
    self.applyingPlaybackCommand = NO;
    NSLog(@"[MeshStreamKit] reset player pause elapsed=%.0fms", (CFAbsoluteTimeGetCurrent() - resetStartedAt) * 1000.0);
    self.pendingPlayerStart = NO;
    self.initialPlayerStartPending = NO;
    self.automaticStartActive = NO;
    self.hasObservedPlaybackState = NO;
    [self stopObservingPlayerItem];
    NSLog(@"[MeshStreamKit] reset observers stopped elapsed=%.0fms", (CFAbsoluteTimeGetCurrent() - resetStartedAt) * 1000.0);
    [self.player replaceCurrentItemWithPlayerItem:nil];
    NSLog(@"[MeshStreamKit] reset item cleared elapsed=%.0fms", (CFAbsoluteTimeGetCurrent() - resetStartedAt) * 1000.0);

    self.p2pEnabled = YES;
    [self.p2pButton setTitle:@"Disable P2P" forState:UIControlStateNormal];
    self.playbackUrlLabel.text = @"Playback URL: -";
    self.lastLoggedHttpDownloaded = 0;
    self.lastLoggedP2pDownloaded = 0;
    self.lastLoggedP2pUploaded = 0;
    self.latestStats = nil;
    [self.statsPeersLabel setText:@"Peers 0"];
    [self.statsTrafficLabel setText:@"P2P down 0 B\nHTTP down 0 B\nP2P up 0 B"];
    [self.statsOffloadLabel setText:@"Offload 0%"];
    [self setSdkEvent:@"Resetting playback" error:NO];
    self.resettingPlayback = NO;
}

- (void)toggleP2P {
    self.p2pEnabled = !self.p2pEnabled;
    [self.session setP2PEnabled:self.p2pEnabled];
    [self.p2pButton setTitle:self.p2pEnabled ? @"Disable P2P" : @"Enable P2P" forState:UIControlStateNormal];
    [self setSdkEvent:self.p2pEnabled ? @"P2P enabled" : @"P2P disabled" error:NO];
}

- (void)refreshStats {
    [self syncPlayerFeedback];
    // P2PClient delivers immutable statistics snapshots through the event
    // listener. Avoid synchronously querying the Rust session from the main
    // queue: the getter takes the session lock and can contend with proxy or
    // tracker work while the UI is handling a tap.
    P2PStats *stats = self.latestStats;
    if (stats == nil) {
        stats = [P2PStats new];
    }
    int64_t totalDown = stats.httpDownloaded + stats.p2pDownloaded;
    NSInteger offload = totalDown > 0 ? (NSInteger)lrint((double)stats.p2pDownloaded * 100.0 / (double)totalDown) : 0;
    if (stats.httpDownloaded != self.lastLoggedHttpDownloaded ||
        stats.p2pDownloaded != self.lastLoggedP2pDownloaded ||
        stats.p2pUploaded != self.lastLoggedP2pUploaded) {
        self.lastLoggedHttpDownloaded = stats.httpDownloaded;
        self.lastLoggedP2pDownloaded = stats.p2pDownloaded;
        self.lastLoggedP2pUploaded = stats.p2pUploaded;
        NSLog(@"[MeshStreamKit] stats http=%lld p2pDown=%lld p2pUp=%lld peers=%ld elapsed=%.0fms",
              stats.httpDownloaded,
              stats.p2pDownloaded,
              stats.p2pUploaded,
              (long)stats.connectedPeers,
              [self elapsedSincePlaybackStartMs]);
    }
    self.statsPeersLabel.text = [NSString stringWithFormat:@"Peers %ld", (long)stats.connectedPeers];
    self.statsTrafficLabel.text = [NSString stringWithFormat:@"P2P down %@\nHTTP down %@\nP2P up %@",
                                  P2PFormatBytes(stats.p2pDownloaded),
                                  P2PFormatBytes(stats.httpDownloaded),
                                  P2PFormatBytes(stats.p2pUploaded)];
    self.statsOffloadLabel.text = [NSString stringWithFormat:@"Offload %ld%%", (long)offload];
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

    dispatch_async(self.playbackWorkQueue, ^{
        [session updateCurrentPositionMs:currentPositionMs];
        [session updateBufferedDurationMs:MAX(0, bufferedDurationMs)];
    });
}

- (void)setStatus:(NSString *)message error:(BOOL)isError {
    self.statusLabel.text = message;
    self.statusLabel.textColor = isError ? [UIColor colorWithRed:176.0 / 255.0 green:28.0 / 255.0 blue:28.0 / 255.0 alpha:1.0] : [UIColor colorWithRed:35.0 / 255.0 green:45.0 / 255.0 blue:48.0 / 255.0 alpha:1.0];
    NSLog(@"[MeshStreamKit] status: %@", message);
}

- (void)playOriginURL:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        [self setStatus:@"CDN fallback URL is invalid" error:YES];
        return;
    }
    [self preparePlayerItemWithURL:url cdnFallback:YES];
    [self setSdkEvent:@"CDN fallback" error:NO];
}

- (void)setSdkEvent:(NSString *)message error:(BOOL)isError {
    self.sdkEventLabel.text = [NSString stringWithFormat:@"SDK event: %@", message];
    self.sdkEventLabel.textColor = isError ? [UIColor colorWithRed:176.0 / 255.0 green:28.0 / 255.0 blue:28.0 / 255.0 alpha:1.0] : [UIColor colorWithRed:70.0 / 255.0 green:83.0 / 255.0 blue:88.0 / 255.0 alpha:1.0];
    NSLog(@"[MeshStreamKit] sdk event: %@", message);
}

- (void)startPlayerPlayback {
    self.applyingPlaybackCommand = YES;
    [self.player playImmediatelyAtRate:1.0];
    self.applyingPlaybackCommand = NO;
}

- (void)handleExplicitPlayerPause {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf handleExplicitPlayerPause]; });
        return;
    }
    if (self.resettingPlayback || self.applyingPlaybackCommand ||
        self.applicationInactive || self.audioInterrupted || self.userPausedPlayback ||
        self.observedItem == nil || self.player.currentItem != self.observedItem) return;
    // An explicit pause must win even before AVPlayer has ever played or
    // while its startup rate is already zero. Generic paused KVO cannot
    // distinguish this intent from an internal failed startup command.
    self.userPausedPlayback = YES;
    self.pendingPlayerStart = NO;
    self.initialPlayerStartPending = NO;
    self.automaticStartActive = NO;
    NSLog(@"[MeshStreamKit] explicit player pause preserved; startup cancelled");
}

- (BOOL)canStartPlayerPlayback {
    return !self.applicationInactive && !self.audioInterrupted &&
           !self.interruptionBlocksStartup && !self.userPausedPlayback;
}

- (void)startInitialPlayerPlaybackIfAllowed {
    if (!self.initialPlayerStartPending || ![self canStartPlayerPlayback] ||
        self.observedItem == nil || self.player.currentItem != self.observedItem ||
        self.observedItem.status == AVPlayerItemStatusFailed) return;
    // Only an explicit Play awaiting its initial command can be deferred.
    // Established playback remains owned by AVKit, including PiP resumption.
    self.initialPlayerStartPending = NO;
    NSLog(@"[MeshStreamKit] starting AVPlayer immediately currentTime=%.3fs",
          CMTimeGetSeconds(self.player.currentTime));
    [self startPlayerPlayback];
}

- (void)resumePendingPlayerStartup {
    // Readiness may have arrived while inactive/interrupted. Reevaluate that
    // pending retry even when the original eager command was already sent.
    // A successful retry consumes both flags, preventing a second command.
    [self startPlayerIfReady:self.observedItem];
    [self startInitialPlayerPlaybackIfAllowed];
}

- (NSTimeInterval)elapsedSincePlaybackStartMs {
    if (self.playbackStartedAt <= 0) {
        return 0;
    }
    return (CFAbsoluteTimeGetCurrent() - self.playbackStartedAt) * 1000.0;
}

#pragma mark - P2PEventListener

- (void)onPlaybackPreparedWithPlaybackUrl:(NSURL *)playbackUrl {
    [self setSdkEvent:[NSString stringWithFormat:@"Playback prepared: %@", playbackUrl.absoluteString] error:NO];
}

- (void)onStatistics:(P2PStats *)stats {
    // Event callbacks are documented to arrive on the main queue. Keep the
    // snapshot and render it directly so the UI never performs a synchronous
    // FFI statistics read.
    self.latestStats = stats;
    [self refreshStats];
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

#pragma mark - Player diagnostics

- (void)applicationWillResignActive:(NSNotification *)notification {
    (void)notification;
    self.applicationInactive = YES;
    NSLog(@"[MeshStreamKit] player lifecycle inactive");
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    self.applicationInactive = NO;
    NSLog(@"[MeshStreamKit] player lifecycle active pausePreserved=%@", self.userPausedPlayback ? @"yes" : @"no");
    [self resumePendingPlayerStartup];
}

- (void)audioSessionInterrupted:(NSNotification *)notification {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf audioSessionInterrupted:notification]; });
        return;
    }
    NSNumber *type = notification.userInfo[AVAudioSessionInterruptionTypeKey];
    if (type == nil) return;
    self.audioInterrupted = type.unsignedIntegerValue == AVAudioSessionInterruptionTypeBegan;
    if (!self.audioInterrupted) {
        NSUInteger options = [notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        // A later interruption must not revive an earlier denied Play.
        // Only a fresh explicit Play clears this latch.
        if ((options & AVAudioSessionInterruptionOptionShouldResume) == 0) {
            self.interruptionBlocksStartup = YES;
        }
        if (self.interruptionBlocksStartup) {
            self.pendingPlayerStart = NO;
            self.automaticStartActive = NO;
        }
    }
    NSLog(@"[MeshStreamKit] player audio interruption=%@", self.audioInterrupted ? @"began" : @"ended");
    if (!self.audioInterrupted) [self resumePendingPlayerStartup];
}

- (void)observePlayerItem:(AVPlayerItem *)item {
    [self stopObservingPlayerItem];
    self.observedItem = item;
    [item addObserver:self
           forKeyPath:@"status"
              options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
              context:P2PPlayerItemStatusContext];
    [item addObserver:self
           forKeyPath:@"presentationSize"
              options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
              context:P2PPlayerItemPresentationSizeContext];
    [item addObserver:self
           forKeyPath:@"playbackLikelyToKeepUp"
              options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
              context:P2PPlayerItemLikelyToKeepUpContext];
}

- (void)stopObservingPlayerItem {
    if (self.observedItem != nil) {
        [self.observedItem removeObserver:self forKeyPath:@"status"];
        [self.observedItem removeObserver:self forKeyPath:@"presentationSize"];
        [self.observedItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        self.observedItem = nil;
    }
}

- (void)startPlayerIfReady:(AVPlayerItem *)item {
    if (!self.pendingPlayerStart || ![self canStartPlayerPlayback] || item == nil || item != self.observedItem || self.player.currentItem != item || item.status == AVPlayerItemStatusFailed) {
        return;
    }
    BOOL ready = item.status == AVPlayerItemStatusReadyToPlay || item.playbackLikelyToKeepUp;
    if (!ready) {
        return;
    }
    self.pendingPlayerStart = NO;
    self.initialPlayerStartPending = NO;
    self.automaticStartActive = NO;
    NSLog(@"[MeshStreamKit] starting AVPlayer after item became playable status=%ld likely=%@ currentTime=%.3fs",
          (long)item.status,
          item.playbackLikelyToKeepUp ? @"yes" : @"no",
          CMTimeGetSeconds(self.player.currentTime));
    [self startPlayerPlayback];
}

- (void)handlePlayerObservationForKeyPath:(NSString *)keyPath
                                  object:(id)object
                                  change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                                 context:(void *)context {
    (void)change;
    if (context == P2PPlayerReadyForDisplayContext) {
        if (object != self.playerController || !self.playerController.isReadyForDisplay ||
            self.playerController.player != self.player || self.observedItem == nil ||
            self.player.currentItem != self.observedItem || self.resettingPlayback || self.didLogFirstFrame) {
            return;
        }
        // Public AVKit signal: a decoded first frame is ready for display.
        // This is not a measurement of the physical screen's scanout time.
        self.didLogFirstFrame = YES;
        [self setStatus:[NSString stringWithFormat:@"AVPlayer first frame ready for display in %.0fms", [self elapsedSincePlaybackStartMs]] error:NO];
        NSLog(@"[MeshStreamKit] AVPlayer first frame readyForDisplay=yes elapsed=%.0fms", [self elapsedSincePlaybackStartMs]);
        self.player.automaticallyWaitsToMinimizeStalling = YES;
        NSLog(@"[MeshStreamKit] AVPlayer stall recovery enabled after first frame ready for display");
        return;
    }
    if (context == P2PPlayerItemStatusContext) {
        AVPlayerItem *item = (AVPlayerItem *)object;
        if (item != self.observedItem) {
            return;
        }
        switch (item.status) {
            case AVPlayerItemStatusReadyToPlay:
                [self setStatus:[NSString stringWithFormat:@"AVPlayer ready in %.0fms", [self elapsedSincePlaybackStartMs]] error:NO];
                [self startPlayerIfReady:item];
                break;
            case AVPlayerItemStatusFailed:
                [self setStatus:[NSString stringWithFormat:@"AVPlayer failed: %@", item.error.localizedDescription ?: @"unknown"] error:YES];
                NSLog(@"[MeshStreamKit] AVPlayer item failed error=%@ logs=%@",
                      item.error,
                      item.errorLog.events);
                break;
            case AVPlayerItemStatusUnknown:
            default:
                NSLog(@"[MeshStreamKit] AVPlayer item status unknown");
                break;
        }
        return;
    }
    if (context == P2PPlayerItemPresentationSizeContext) {
        AVPlayerItem *item = (AVPlayerItem *)object;
        if (item != self.observedItem) {
            return;
        }
        CGSize presentationSize = item.presentationSize;
        if (!self.didLogVideoMetadata && presentationSize.width > 0.0 && presentationSize.height > 0.0) {
            self.didLogVideoMetadata = YES;
            NSLog(@"[MeshStreamKit] AVPlayer video metadata ready size=%.0fx%.0f elapsed=%.0fms",
                  presentationSize.width,
                  presentationSize.height,
                  [self elapsedSincePlaybackStartMs]);
            // Dimensions can arrive before the item is playable. Consuming
            // the only retry here while status is Unknown can cause another
            // SetRateFailed and leave no retry for ReadyToPlay. Use the same
            // playable/lifecycle/user-pause gate as status notifications.
            [self startPlayerIfReady:item];
        }
        return;
    }
    if (context == P2PPlayerItemLikelyToKeepUpContext) {
        AVPlayerItem *item = (AVPlayerItem *)object;
        if (item != self.observedItem) {
            return;
        }
        if (item.playbackLikelyToKeepUp) {
            NSLog(@"[MeshStreamKit] AVPlayer item likelyToKeepUp elapsed=%.0fms",
                  [self elapsedSincePlaybackStartMs]);
            [self startPlayerIfReady:item];
        }
        return;
    }
    if (context == P2PPlayerTimeControlContext) {
        if (object != self.player) {
            return;
        }
        NSString *status = @"unknown";
        if (self.player.timeControlStatus == AVPlayerTimeControlStatusPaused) {
            status = @"paused";
        } else if (self.player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate) {
            status = @"waiting";
        } else if (self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
            status = @"playing";
        }
        NSLog(@"[MeshStreamKit] AVPlayer timeControlStatus=%@ reason=%@ elapsed=%.0fms",
              status,
              self.player.reasonForWaitingToPlay ?: @"-",
              [self elapsedSincePlaybackStartMs]);
        if (self.player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate ||
            self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
            self.hasObservedPlaybackState = YES;
        }
        NSLog(@"[MeshStreamKit] AVPlayer startup itemStatus=%ld rate=%.3f autoStart=%@",
              (long)self.observedItem.status,
              self.player.rate,
              self.automaticStartActive ? @"yes" : @"no");
        if (self.player.timeControlStatus == AVPlayerTimeControlStatusPaused &&
            !self.applyingPlaybackCommand &&
            !self.resettingPlayback &&
            !self.automaticStartActive &&
            self.hasObservedPlaybackState) {
            if (self.applicationInactive || self.audioInterrupted) {
                NSLog(@"[MeshStreamKit] system pause observed source=%@",
                      self.audioInterrupted ? @"audio-interruption" : @"application-inactive");
                return;
            }
            self.userPausedPlayback = YES;
            self.automaticStartActive = NO;
            self.pendingPlayerStart = NO;
            // AVKit exposes no public callback identifying a controls tap.
            // Preserve an unclassified pause conservatively; do not claim
            // every paused KVO notification proves a user action.
            NSLog(@"[MeshStreamKit] unclassified player pause preserved");
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if (![NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (self == nil) {
                return;
            }
            [self handlePlayerObservationForKeyPath:keyPath object:object change:change context:context];
        });
        return;
    }
    [self handlePlayerObservationForKeyPath:keyPath object:object change:change context:context];
}

@end
