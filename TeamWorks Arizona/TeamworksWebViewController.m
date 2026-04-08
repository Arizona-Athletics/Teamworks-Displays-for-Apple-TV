//
//  TeamworksWebViewController.m
//  TeamWorks Arizona
//
//  Created by Jason Cantor on 1/21/26.
//

#import "TeamworksWebViewController.h"
#import <objc/message.h>

// UIWebView is private on tvOS. Use runtime lookup to avoid compile-time unavailability.
@interface TeamworksWebViewController ()
@property (nonatomic, strong) UIView *webView;
@property (nonatomic, strong) NSTimer *autoplayTimer;
@property (nonatomic, strong) NSTimer *loadDelayTimer;
@property (nonatomic, assign) NSInteger autoplayAttempts;
@property (nonatomic, strong) UILabel *loadingLabel;
@end

static BOOL hasCompletedInitialLoad = NO;

@implementation TeamworksWebViewController

- (UIView *)createWebView {
    Class wkConfigClass = NSClassFromString(@"WKWebViewConfiguration");
    Class wkWebViewClass = NSClassFromString(@"WKWebView");
    if (wkConfigClass && wkWebViewClass) {
        id config = [[wkConfigClass alloc] init];
        @try { [config setValue:@0 forKey:@"mediaTypesRequiringUserActionForPlayback"]; } @catch (__unused NSException *e) {}
        @try { [config setValue:@(NO) forKey:@"requiresUserActionForMediaPlayback"]; } @catch (__unused NSException *e) {}
        @try { [config setValue:@(YES) forKey:@"allowsInlineMediaPlayback"]; } @catch (__unused NSException *e) {}

        SEL initSelector = NSSelectorFromString(@"initWithFrame:configuration:");
        if ([wkWebViewClass instancesRespondToSelector:initSelector]) {
            id (*msgSend)(id, SEL, CGRect, id) = (void *)objc_msgSend;
            return msgSend([wkWebViewClass alloc], initSelector, self.view.bounds, config);
        }
    }

    Class uiWebViewClass = NSClassFromString(@"UIWebView");
    if (uiWebViewClass) {
        return [[uiWebViewClass alloc] initWithFrame:self.view.bounds];
    }

    return nil;
}

- (instancetype)initWithURL:(NSString *)urlString {
    self = [super init];
    if (self) {
        _urlString = urlString;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    UIView *webView = [self createWebView];
    if (!webView) {
        UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
        label.text = @"Web view unavailable on this tvOS build.";
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        [self.view addSubview:label];
        return;
    }

    self.webView = webView;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor blackColor];
    [self.webView setValue:@(NO) forKey:@"opaque"];
    if ([self.webView respondsToSelector:NSSelectorFromString(@"setScalesPageToFit:")]) {
        [self.webView setValue:@(YES) forKey:@"scalesPageToFit"];
    }

    // Configure scroll view for Apple TV remote
    UIScrollView *scrollView = [self.webView valueForKey:@"scrollView"];
    if ([scrollView isKindOfClass:[UIScrollView class]]) {
        scrollView.bounces = NO;
        scrollView.scrollEnabled = YES;
        scrollView.panGestureRecognizer.allowedTouchTypes = @[@(UITouchTypeIndirect)];
        scrollView.backgroundColor = [UIColor blackColor];
        scrollView.contentInset = UIEdgeInsetsZero;
        scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
        if (@available(tvOS 11.0, *)) {
            scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
    }

    [self.view addSubview:self.webView];

    if (!hasCompletedInitialLoad) {
        // First app startup - show loading screen for network connection
        self.loadingLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
        self.loadingLabel.text = @"Loading…";
        self.loadingLabel.textAlignment = NSTextAlignmentCenter;
        self.loadingLabel.numberOfLines = 0;
        self.loadingLabel.textColor = [UIColor whiteColor];
        self.loadingLabel.backgroundColor = [UIColor blackColor];
        [self.view addSubview:self.loadingLabel];
        [self scheduleInitialLoad];
    } else {
        // Subsequent loads - skip loading screen
        [self performLoad];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.webView.frame = self.view.bounds;
    if (self.loadingLabel) {
        self.loadingLabel.frame = self.view.bounds;
    }
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (presses.anyObject.type == UIPressTypePlayPause) {
        [self tryAutoplay];
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

- (void)scheduleInitialLoad {
    if (self.loadDelayTimer) {
        [self.loadDelayTimer invalidate];
        self.loadDelayTimer = nil;
    }
    self.loadDelayTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                           target:self
                                                         selector:@selector(performLoad)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (void)performLoad {
    if (self.loadingLabel) {
        [self.loadingLabel removeFromSuperview];
        self.loadingLabel = nil;
    }
    hasCompletedInitialLoad = YES;

    if (self.urlString.length > 0) {
        NSURL *url = [NSURL URLWithString:self.urlString];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        SEL loadRequestSelector = NSSelectorFromString(@"loadRequest:");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if ([self.webView respondsToSelector:loadRequestSelector]) {
            [self.webView performSelector:loadRequestSelector withObject:request];
        }
#pragma clang diagnostic pop
    }

    [self startAutoplayLoop];
}

- (void)startAutoplayLoop {
    if (self.autoplayTimer) {
        return;
    }
    self.autoplayTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                          target:self
                                                        selector:@selector(tryAutoplay)
                                                        userInfo:nil
                                                         repeats:YES];
    [self tryAutoplay];
}

- (void)tryAutoplay {
    NSString *js = @"(function(){"
                   "var foundYT=false;"
                   "function addParam(url,key,val){"
                   " if(url.indexOf(key+'=')!==-1){return url;}"
                   " return url + (url.indexOf('?')!==-1?'&':'?') + key + '=' + val;"
                   "}"
                   "function getYouTubeId(url){"
                   " var m=url.match(/\\/embed\\/([a-zA-Z0-9_-]+)/);"
                   " return m?m[1]:null;"
                   "}"
                   "var iframes=document.querySelectorAll('iframe');"
                   "for(var i=0;i<iframes.length;i++){"
                   " var src=iframes[i].getAttribute('src')||'';"
                   " if(src.indexOf('youtube.com/embed')!==-1||src.indexOf('youtube-nocookie.com/embed')!==-1){"
                   "   foundYT=true;"
                   "   if(src.indexOf('autoplay=1')===-1){"
                   "     var nsrc=src;"
                   "     nsrc=addParam(nsrc,'autoplay','1');"
                   "     nsrc=addParam(nsrc,'mute','0');"
                   "     nsrc=addParam(nsrc,'playsinline','1');"
                   "     nsrc=addParam(nsrc,'enablejsapi','1');"
                   "     nsrc=addParam(nsrc,'controls','0');"
                   "     nsrc=addParam(nsrc,'rel','0');"
                   "     try{ nsrc=addParam(nsrc,'origin',encodeURIComponent(location.origin)); }catch(e){}"
                   "     iframes[i].setAttribute('src',nsrc);"
                   "   }"
                   "   iframes[i].setAttribute('allow','autoplay; encrypted-media; picture-in-picture');"
                   "   try{"
                   "     var win=iframes[i].contentWindow;"
                   "     if(win){"
                   "       win.postMessage('{\"event\":\"command\",\"func\":\"unMute\",\"args\":\"\"}','*');"
                   "       win.postMessage('{\"event\":\"command\",\"func\":\"playVideo\",\"args\":\"\"}','*');"
                   "     }"
                   "   }catch(e){}"
                   " }"
                   "}"
                   "var v=document.querySelectorAll('video');"
                   "for(var j=0;j<v.length;j++){"
                   " try{v[j].muted=false; v[j].playsInline=true; var p=v[j].play();"
                   " if(p&&p.catch){p.catch(function(){});} }catch(e){} }"
                   "if(foundYT){"
                   " try{"
                   "   if(!window.__twYTRefreshInit){"
                   "     window.__twYTRefreshInit=true;"
                   "     window.__twYTRefreshPending=false;"
                   "     window.__twYTPlayers=window.__twYTPlayers||{};"
                   "     window.__twYTRefreshEnsurePlayers=function(){"
                   "       if(!(window.YT&&window.YT.Player)){return;}"
                   "       var list=document.querySelectorAll('iframe');"
                   "       for(var k=0;k<list.length;k++){"
                   "         var s=list[k].getAttribute('src')||'';"
                   "         if(s.indexOf('youtube.com/embed')===-1&&s.indexOf('youtube-nocookie.com/embed')===-1){continue;}"
                   "         var id=list[k].getAttribute('id');"
                   "         if(!id){ id='tw-yt-'+Math.random().toString(36).slice(2); list[k].setAttribute('id',id); }"
                   "         if(window.__twYTPlayers[id]){continue;}"
                   "         window.__twYTPlayers[id]=new YT.Player(id,{events:{onStateChange:function(e){"
                   "           if(e&&e.data===0){"
                   "             if(window.__twYTRefreshPending){return;}"
                   "             window.__twYTRefreshPending=true;"
                   "             setTimeout(function(){location.reload();},500);"
                   "           }"
                   "         }}});"
                   "       }"
                   "     };"
                   "     if(window.YT&&window.YT.Player){"
                   "       window.__twYTRefreshEnsurePlayers();"
                   "     } else {"
                   "       var prevReady=window.onYouTubeIframeAPIReady;"
                   "       window.onYouTubeIframeAPIReady=function(){"
                   "         if(prevReady){try{prevReady();}catch(e){}}"
                   "         if(window.__twYTRefreshEnsurePlayers){window.__twYTRefreshEnsurePlayers();}"
                   "       };"
                   "       var tag=document.createElement('script');"
                   "       tag.src='https://www.youtube.com/iframe_api';"
                   "       var firstScript=document.getElementsByTagName('script')[0];"
                   "       if(firstScript&&firstScript.parentNode){firstScript.parentNode.insertBefore(tag,firstScript);}"
                   "       else{document.head.appendChild(tag);}"
                   "     }"
                   "   }"
                   "   if(window.__twYTRefreshEnsurePlayers){window.__twYTRefreshEnsurePlayers();}"
                   " }catch(e){}"
                   "}"
                   "return foundYT?1:0;"
                   "})();";

    SEL evaluateSelector = NSSelectorFromString(@"evaluateJavaScript:completionHandler:");
    if ([self.webView respondsToSelector:evaluateSelector]) {
        void (^completion)(id, NSError *) = ^(id result, NSError *error) {};
        void (*msgSend)(id, SEL, id, id) = (void *)objc_msgSend;
        msgSend(self.webView, evaluateSelector, js, completion);
        return;
    }

    SEL legacySelector = NSSelectorFromString(@"stringByEvaluatingJavaScriptFromString:");
    if ([self.webView respondsToSelector:legacySelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.webView performSelector:legacySelector withObject:js];
#pragma clang diagnostic pop
    }
}

@end
