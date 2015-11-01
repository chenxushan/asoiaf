//
//  MainViewController.m
//  ice
//
//  Created by Vicent Tsai on 15/10/25.
//  Copyright © 2015年 HeZhi Corp. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "NSArray+Random.h"

#import "MainViewController.h"
#import "SlideMenuViewController.h"
#import "GalleryViewController.h"

#import "DataManager.h"
#import "FeaturedQuoteModel.h"

#define SLIDE_TIMING 0.25
#define OVERLAY_ALPHA_BEGAN 0.0
#define OVERLAY_ALPHA_END 0.7

@interface MainViewController () <UIGestureRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *centerView;
@property (weak, nonatomic) IBOutlet UILabel *quoteLabel;
@property (weak, nonatomic) IBOutlet UILabel *authorLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *featuredQuoteActivity;

@property (nonatomic, strong) GalleryViewController *galleryViewController;

@property (nonatomic, strong) SlideMenuViewController *slideMenuViewController;
@property (nonatomic, assign) BOOL showingSlideMenu;
@property (nonatomic, assign) BOOL showMenu;
@property (nonatomic, assign) CGPoint preVelocity;

@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, assign) CGFloat overlayAlphaSpeed;

@end

@implementation MainViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) {
        UINavigationItem *navItem = self.navigationItem;
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:@"\u2630"
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(btnMoveMenuRight:)];
        bbi.tag = 1;
        navItem.leftBarButtonItem = bbi;
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    [self setupGalleryView];
    [self setupOverlayView];
    [self setupFeaturedQuoteLabel];

    [self setupGestures];
}

#pragma mark - Button Actions

- (void)btnMoveMenuRight:(id)sender
{
    UIButton *button = sender;
    switch (button.tag) {
        case 0: {
            [self moveMenuToOriginalPosition];
            break;
        }

        case 1: {
            [self moveMenuRight];
            break;
        }

        default:
            break;
    }
}

#pragma mark - Menu Actions

- (void)moveMenuToOriginalPosition
{
    UIView *childView = [self getSlideMenuView];

    [UIView animateWithDuration:SLIDE_TIMING delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         childView.frame = CGRectOffset(childView.frame, -childView.frame.size.width, 0);
                         self.overlayView.alpha = OVERLAY_ALPHA_BEGAN;
                     }
                     completion:^(BOOL finished) {
                         if (finished) {
                             [self resetMainView];
                         }
                     }];
}

- (void)moveMenuRight
{
    UIView *childView = [self getSlideMenuView];

    [UIView animateWithDuration:SLIDE_TIMING delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         childView.frame = CGRectMake(0, 0,
                                                      childView.frame.size.width, childView.frame.size.height);
                         self.overlayView.alpha = OVERLAY_ALPHA_END;
                     } completion:^(BOOL finished) {
                         if (finished) {
                             self.navigationItem.leftBarButtonItem.tag = 0;
                         }
                     }];
}

#pragma mark - Setup View

- (void)resetMainView
{
    if (self.slideMenuViewController != nil) {
        [self.slideMenuViewController.view removeFromSuperview];
        self.slideMenuViewController = nil;

        [self.overlayView removeFromSuperview];

        self.navigationItem.leftBarButtonItem.tag = 1;
        self.showingSlideMenu = NO;
    }
}

- (UIView *)getSlideMenuView
{
    if (self.slideMenuViewController == nil) {
        self.slideMenuViewController = [[SlideMenuViewController alloc] initWithNibName:@"SlideMenuViewController" bundle:nil];

        [self.centerView addSubview:self.slideMenuViewController.view];

        [self addChildViewController:self.slideMenuViewController];
        [self.slideMenuViewController didMoveToParentViewController:self];

        self.slideMenuViewController.view.frame = CGRectOffset(self.slideMenuViewController.view.frame,
                                                               -self.slideMenuViewController.view.frame.size.width, 0);

        CGFloat slideMenuWidth = self.slideMenuViewController.view.frame.size.width;
        self.overlayAlphaSpeed = fabs(OVERLAY_ALPHA_BEGAN - OVERLAY_ALPHA_END) / slideMenuWidth;

        [self setupSlideMenuGestures:self.slideMenuViewController.view];
    }

    self.showingSlideMenu = YES;

    UIView *view = self.slideMenuViewController.view;

    [self.centerView addSubview:self.overlayView];
    [self.centerView bringSubviewToFront:view];

    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOpacity = 0.8;
    view.layer.shadowOffset = CGSizeMake(.2, .2);

    return view;
}

- (void)setupGalleryView
{
    self.galleryViewController = [[GalleryViewController alloc] init];
    [self.centerView addSubview:self.galleryViewController.view];
    [self didMoveToParentViewController:self.galleryViewController];
}

- (void)setupOverlayView
{
    self.overlayView = [[UIView alloc] initWithFrame:self.navigationController.view.frame];
    self.overlayView.backgroundColor = [UIColor blackColor];
    self.overlayView.alpha = OVERLAY_ALPHA_BEGAN;
}

- (void)setupFeaturedQuoteLabel
{
    [self.featuredQuoteActivity startAnimating];
    [self.quoteLabel setHidden:YES];
    [self.authorLabel setHidden:YES];

    [[DataManager sharedManager] getFeaturedQuotes:^(NSArray *featuredQuotes) {
        FeaturedQuoteModel *featuredQuote = [featuredQuotes randomObject];
        self.quoteLabel.text = featuredQuote.quote;
        self.authorLabel.text = [NSString stringWithFormat:@"——%@", featuredQuote.author];
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"getFeaturedQuotes"
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
                                                      [self.featuredQuoteActivity stopAnimating];
                                                      [self.featuredQuoteActivity setHidden:YES];

                                                      CATransition *animation = [CATransition animation];
                                                      animation.type = kCATransitionFade;
                                                      animation.duration = 0.4;
                                                      
                                                      [self.quoteLabel.layer addAnimation:animation forKey:nil];
                                                      [self.authorLabel.layer addAnimation:animation forKey:nil];

                                                      [self.quoteLabel setHidden:NO];
                                                      [self.authorLabel setHidden:NO];
                                                  }];
}

- (void)hideLoadingActivity
{
}

#pragma mark - Swipe Gesture Setup/Actions
#pragma mark - setup

- (void)setupGestures
{
    UIScreenEdgePanGestureRecognizer *edgePanRecognizer = [[UIScreenEdgePanGestureRecognizer alloc]
                                                           initWithTarget:self
                                                           action:@selector(screenEdgeSwiped:)];
    edgePanRecognizer.edges = UIRectEdgeLeft;
    [self.centerView addGestureRecognizer:edgePanRecognizer];

    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(mainViewTapped:)];
    tapRecognizer.cancelsTouchesInView = NO;
    [self.centerView addGestureRecognizer:tapRecognizer];
}

- (void)setupSlideMenuGestures:(UIView *)menuView
{
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(movelMenu:)];
    [panRecognizer setMinimumNumberOfTouches:1];
    [panRecognizer setMaximumNumberOfTouches:1];
    [panRecognizer setDelegate:self];

    [menuView addGestureRecognizer:panRecognizer];
}

- (void)movelMenu:(UIGestureRecognizer *)sender
{
    [[[(UITapGestureRecognizer *)sender view] layer] removeAllAnimations];

    CGPoint translatedPoint = [(UIPanGestureRecognizer *)sender translationInView:self.centerView];
    CGPoint velocity = [(UIPanGestureRecognizer *)sender velocityInView:self.centerView];

    if (sender.state == UIGestureRecognizerStateEnded) {
        if (velocity.x > 0) {
            NSLog(@"gesture went right");
        } else {
            NSLog(@"gesture went left");
        }

        if (!self.showMenu) {
            [self moveMenuToOriginalPosition];
        } else {
            if (self.showingSlideMenu) {
                [self moveMenuRight];
            }
        }
    }

    if (sender.state == UIGestureRecognizerStateChanged) {
        self.showMenu = sender.view.center.x > 0;

        [sender view].center = CGPointMake([sender view].center.x + translatedPoint.x, [sender view].center.y);
        [(UIPanGestureRecognizer *)sender setTranslation:CGPointZero inView:self.centerView];

        self.overlayView.alpha += self.overlayAlphaSpeed * translatedPoint.x;
        if (self.overlayView.alpha > OVERLAY_ALPHA_END) {
            self.overlayView.alpha = OVERLAY_ALPHA_END;
        }

        self.preVelocity = velocity;

        if (sender.view.frame.origin.x >= 0) {
            sender.view.frame = CGRectMake(0, sender.view.frame.origin.y,
                                           sender.view.frame.size.width, sender.view.frame.size.height);
        }
    }

}

- (void)screenEdgeSwiped:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        if (!self.showingSlideMenu) {
            [self moveMenuRight];
        }
    }
}

- (void)mainViewTapped:(UIGestureRecognizer *)sender
{
    CGPoint location = [sender locationInView:self.centerView];
    if (self.showingSlideMenu) {
        if (CGRectContainsPoint(self.centerView.frame, location) &&
            !CGRectContainsPoint(self.slideMenuViewController.view.frame, location)) {
            [self moveMenuToOriginalPosition];
        }
    }
}

@end