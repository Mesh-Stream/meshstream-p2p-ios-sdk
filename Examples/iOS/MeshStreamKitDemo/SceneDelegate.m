#import "SceneDelegate.h"
#import "P2PDemoViewController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
             options:(UISceneConnectionOptions *)connectionOptions {
    (void)session;
    (void)connectionOptions;
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    if (![windowScene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.rootViewController = [P2PDemoViewController new];
    [self.window makeKeyAndVisible];
}

@end
