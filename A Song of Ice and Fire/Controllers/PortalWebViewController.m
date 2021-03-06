//
//  PortalWebViewController.m
//  A Song of Ice and Fire
//
//  Created by Vicent Tsai on 15/12/19.
//  Copyright © 2015年 HeZhi Corp. All rights reserved.
//

#import <WebKit/WebKit.h>

#import "PortalWebViewController.h"
#import "WikiViewController.h"
#import "CategoryMemberModel.h"

#import "DataManager.h"
#import "Spinner.h"

/* Custom Category */
#import "WKWebView+SynchronousEvaluateJavaScript.h"

/* Pods */
#import "JTSImageViewController.h"

@interface PortalWebViewController () <WKNavigationDelegate>

@property (nonatomic, assign) CGFloat compensationHeight;

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) Spinner *cubeSpinner;
@property (nonatomic, strong) UIView *statusBackgroundView;

@end

@implementation PortalWebViewController

- (instancetype)initWithPortal:(PortalModel *)portal;
{
    self = [super init];
    if (self) {
        _portal = portal;
        _cubeSpinner = [Spinner cubeSpinner];
    }
    return self;
}

#pragma mark - View Manager

- (void)viewDidLoad {
    [super viewDidLoad];

    // 避免进入其他页面再返回时 self.webView.scrollView 自动调整 contentInset 而出现难看的空白
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.cubeSpinner.center = CGPointMake([[UIScreen mainScreen] bounds].size.width / 2,
                                          [[UIScreen mainScreen] bounds].size.height / 2);
    [self.view addSubview:self.cubeSpinner];
    [self.cubeSpinner startAnimating];


    CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
    CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    self.compensationHeight = navBarHeight + statusBarHeight;

    [self setupWebView];
    [self setupStatusBar];
    [self setupGestures];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    self.navigationController.navigationBar.barStyle = UIStatusBarStyleDefault;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/* 设置 status bar 颜色 */
- (UIStatusBarStyle)preferredStatusBarStyle
{
    CGPoint offset = self.webView.scrollView.contentOffset;

    if (offset.y < 270) {
        return UIStatusBarStyleLightContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

- (void)setupWebView
{
    self.webView = [[WKWebView alloc] initWithFrame:self.view.frame];
    self.webView.navigationDelegate = self;
    self.webView.alpha = 0.0;

    CGRect frame = self.view.frame;
    frame.size.width = [UIScreen mainScreen].bounds.size.width;
    frame.size.height = [UIScreen mainScreen].bounds.size.height;
    frame.origin.y = 0;
    self.webView.frame = frame;

    // 解决隐藏 navigation bar 后出现空白的问题
    // 注：本地测试无问题，但上传商店后出现此问题
    [self.webView.scrollView setContentInset:UIEdgeInsetsMake(-self.compensationHeight, 0, 0, 0)];
    [self.webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(-self.compensationHeight, 0, 0, 0)];


    self.webView.scrollView.bounces = NO;
    [self.webView.scrollView addObserver:self
                              forKeyPath:@"contentOffset"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];

    // Main bundle
    NSBundle *mainBundle = [NSBundle mainBundle];

#ifdef DEBUG
    NSString *cssPath = [mainBundle pathForResource:@"wikiview" ofType:@"css"];
#else
    NSString *cssPath = [mainBundle pathForResource:@"wikiview-min" ofType:@"css"];
#endif

    NSString *css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:nil];

    NSString *portalTemplatePath = [mainBundle pathForResource:@"portal_template" ofType:@"html"];
    NSMutableString *portalTemplate = [NSMutableString stringWithContentsOfFile:portalTemplatePath encoding:NSUTF8StringEncoding error:nil];

    [portalTemplate replaceOccurrencesOfString:@"[[[css]]]"
                                    withString:css
                                       options:NSLiteralSearch
                                         range:NSMakeRange(0, portalTemplate.length)];

    [[MainManager sharedManager] getWikiEntry:self.portal.link completionBlock:^(NSString *wikiEntry) {
        
        NSString *formattedWikiEntry = [self formatHtml:wikiEntry];

        [portalTemplate replaceOccurrencesOfString:@"[[[content]]]"
                                        withString:formattedWikiEntry
                                           options:NSLiteralSearch
                                             range:NSMakeRange(0, portalTemplate.length)];
        [self.webView loadHTMLString:portalTemplate baseURL:[NSURL fileURLWithPath:cssPath]];
        [self.view addSubview:self.webView];
        [UIView animateWithDuration:1.2 animations:^{
            self.webView.alpha = 1.0;
        }];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.cubeSpinner stopAnimating];
            [self.cubeSpinner setHidden:YES];
            [self.cubeSpinner removeFromSuperview];
        });

    }];
}

- (void)setupStatusBar
{
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    CGRect frame = CGRectMake(0, 0, statusBarSize.width, statusBarSize.height);
    self.statusBackgroundView = [[UIView alloc] initWithFrame:frame];
    self.statusBackgroundView.backgroundColor = [UIColor whiteColor];
    self.statusBackgroundView.alpha = 0.0;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (![@"contentOffset" isEqualToString:keyPath])return;

    CGFloat headerHeight = 270;
    CGPoint offset = self.webView.scrollView.contentOffset;
    UIStatusBarStyle barStyle = (UIStatusBarStyle)self.navigationController.navigationBar.barStyle;

    if (offset.y >= headerHeight && barStyle == UIStatusBarStyleLightContent) {
        [self.view addSubview:self.statusBackgroundView];
        [UIView animateWithDuration:0.25 animations:^{
            self.navigationController.navigationBar.barStyle = UIStatusBarStyleDefault;
            self.statusBackgroundView.alpha = 1.0;
        }];
    } else if (offset.y < headerHeight && barStyle == UIStatusBarStyleDefault) {
        self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
        self.statusBackgroundView.alpha = 0.0;
        [self.statusBackgroundView removeFromSuperview];
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURLRequest *request = navigationAction.request;
    NSString *url = [[request URL] absoluteString];
    NSString *prefix = @"http://asoiaf.huiji.wiki/wiki/";

    if ((navigationAction.navigationType == WKNavigationTypeLinkActivated)) {
        // Check if the clicked link is a image or not
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\.(jpg|gif|png)"
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:url options:0 range:NSMakeRange(0, [url length])];

        // All internal links except IMAGE could create new wiki view controller
        if ([url hasPrefix:prefix] && !match) {
            NSString *link = [[url substringFromIndex:[prefix length]] stringByRemovingPercentEncoding];
            WikiViewController *wikiVC = [[WikiViewController alloc] initWithTitle:link andLink:link];
            wikiVC.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"home_button"]
                                                                                        style:UIBarButtonItemStylePlain
                                                                                       target:self
                                                                                       action:@selector(homeButtonPressed:)];

            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:wikiVC];
            [self presentViewController:nav animated:YES completion:nil];
        }

        decisionHandler(WKNavigationActionPolicyCancel);
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - Controller Actions

- (void)homeButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Setup Gestures

- (void)setupGestures
{
    UITapGestureRecognizer* singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.cancelsTouchesInView = NO;

    [self.webView addGestureRecognizer:singleTap];
}

-(void)handleSingleTap:(UITapGestureRecognizer *)sender
{
    CGPoint pt = [sender locationInView:self.webView];
    NSString *imgSrcScript = [NSString stringWithFormat:@"document.elementFromPoint(%f, %f).src", pt.x, pt.y];
    NSString *imageSource = [self.webView stringByEvaluatingJavaScriptFromString:imgSrcScript];
    if (imageSource.length > 0) {
        // Create image info
        JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
        imageInfo.imageURL = [NSURL URLWithString:imageSource];

        imageInfo.referenceRect = self.webView.frame;
        imageInfo.referenceView = self.webView.superview;

        // Setup view controller
        JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                               initWithImageInfo:imageInfo
                                               mode:JTSImageViewControllerMode_Image
                                               backgroundStyle:JTSImageViewControllerBackgroundOption_Scaled];

        // Present the view controller.
        [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
    }
}

#pragma mark - Helper

- (NSString *)formatHtml:(NSString *)html
{
    NSString *baseUrl = @"http://asoiaf.huiji.wiki";
    NSString *wikiString = [NSString stringWithFormat:@"%@/wiki/", baseUrl];
    NSString *ahrefWikiString = [NSString stringWithFormat:@"<a href=\"%@/wiki\"", baseUrl];
    NSString *ahrefWikiStringReplacement = [NSString stringWithFormat:@"<a target=\"blank\" href=\"%@/wiki\"", baseUrl];
    
    NSString *formatedHtml = [html stringByReplacingOccurrencesOfString:@"/wiki/" withString:wikiString];
    formatedHtml = [formatedHtml stringByReplacingOccurrencesOfString:ahrefWikiString withString:ahrefWikiStringReplacement];
    formatedHtml = [formatedHtml stringByReplacingOccurrencesOfString:@"class=\"mw-editsection\"" withString:@"style=\"visibility: hidden\""];

    return formatedHtml;
}

#pragma mark - Deinit

- (void)dealloc
{
    [self.webView.scrollView removeObserver:self forKeyPath:@"contentOffset"];
}

@end
