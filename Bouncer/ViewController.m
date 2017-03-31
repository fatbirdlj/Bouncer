//
//  ViewController.m
//  Bouncer
//
//  Created by 刘江 on 2017/3/26.
//  Copyright © 2017年 Flicker. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>

@interface ViewController ()
@property (weak,nonatomic) UIView *redBlock;
@property (weak,nonatomic) UIView *blackBlock;
@property (strong,nonatomic) CMMotionManager *motionManager;
@property (strong,nonatomic) UIDynamicAnimator *animator;
@property (weak,nonatomic) UIGravityBehavior *gravity;
@property (weak,nonatomic) UICollisionBehavior *collision;
@property (weak,nonatomic) UIDynamicItemBehavior *elastic;
@property (weak,nonatomic) UIDynamicItemBehavior *quicksand;

// scoring properties
@property (weak,nonatomic) UILabel *scoreLabel;
@property (nonatomic) double lastScore;
@property (nonatomic) double maxScore;
@property (nonatomic) double blackBlockDistanceTraveled;
@property (nonatomic, strong) NSDate *lastRecordedBlackBlockTravelTime;
@property (nonatomic) double cumulativeBlackBlockTravelTime;
@property (weak,nonatomic) UIDynamicItemBehavior *blackBlockTracker;
@property (weak,nonatomic) UICollisionBehavior *scoreBoundary;
@property (nonatomic) CGPoint scoreBoundaryCenter;
@end

@implementation ViewController

#pragma mark - Setter and Getter

- (CMMotionManager *)motionManager{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.accelerometerUpdateInterval = 0.1;
    }
    return _motionManager;
}

- (UIDynamicAnimator *)animator{
    if (!_animator) {
        _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    }
    return _animator;
}

- (UIGravityBehavior *)gravity{
    if (!_gravity) {
        UIGravityBehavior *gravity = [[UIGravityBehavior alloc] init];
        [self.animator addBehavior:gravity];
        self.gravity = gravity;
    }
    return _gravity;
}

- (UICollisionBehavior *)collision{
    if (!_collision) {
        UICollisionBehavior *collision = [[UICollisionBehavior alloc] init];
        collision.translatesReferenceBoundsIntoBoundary = YES;
        [self.animator addBehavior:collision];
        self.collision = collision;
    }
    return _collision;
}

- (UIDynamicItemBehavior *)elastic{
    if (!_elastic) {
        UIDynamicItemBehavior *elastic = [[UIDynamicItemBehavior alloc] init];
        [self.animator addBehavior:elastic];
        self.elastic = elastic;
        [self resetElasticity];
    }
    return _elastic;
}

- (UIDynamicItemBehavior *)quicksand{
    if (!_quicksand) {
        UIDynamicItemBehavior *quicksand = [[UIDynamicItemBehavior alloc] init];
        quicksand.resistance = 0;
        [self.animator addBehavior:quicksand];
        self.quicksand = quicksand;
    }
    return _quicksand;
}

#pragma mark - Initialise

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap)]];
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap)];
    doubleTap.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTap];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
        [self pauseGame];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
        if(self.view.window) [self resumeGame];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note){
        [self resetElasticity];
    }];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self pauseGame];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self resumeGame];
}

#pragma mark - Gesture

- (void)tap{
    if (![self isPaused]) [self pauseGame];
    else [self resumeGame];
}

- (void)doubleTap{
    
    if(![self isPaused]) [self pauseGame];
    
    // UIAlertView deprecated
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bouncer"
                                                                   message:@"Restart Game?" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Yes"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
                                                          [self restartGame];
                                                      }];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No"
                                                       style:UIAlertActionStyleCancel
                                                     handler:nil];
    
    [alert addAction:yesAction];
    [alert addAction:noAction];
}

#pragma mark - Block Creation

static CGSize blockSize = {40,40};
- (UIView *)addBlockOffsetFromCenterBy: (UIOffset)offset{
    CGPoint blockCenter = CGPointMake(CGRectGetMidX(self.view.bounds),
                                      CGRectGetMidY(self.view.bounds));
    CGRect blockRect = CGRectMake(blockCenter.x - blockSize.width/2 + offset.horizontal,
                                  blockCenter.y - blockSize.height/2 + offset.vertical,
                                  blockSize.width,
                                  blockSize.height);
    
    UIView *block = [[UIView alloc] initWithFrame:blockRect];
    [self.view addSubview:block];
    return block;
}

#pragma mark - Status

- (BOOL)isPaused{
    return !self.motionManager.accelerometerActive;
}

- (void)resumeGame{
    if (!self.redBlock) {
        self.redBlock = [self addBlockOffsetFromCenterBy:UIOffsetMake(-100, 0)];
        self.redBlock.backgroundColor = [UIColor redColor];
        [self.gravity addItem:self.redBlock];
        [self.collision addItem:self.redBlock];
        [self.elastic addItem:self.redBlock];
        [self.quicksand addItem:self.redBlock];
        self.blackBlock = [self addBlockOffsetFromCenterBy:UIOffsetMake(+100, 0)];
        self.blackBlock.backgroundColor = [UIColor blackColor];
        [self.collision addItem:self.blackBlock];
        [self.quicksand addItem:self.blackBlock];
    }
    
    self.quicksand.resistance = 0;
    self.gravity.gravityDirection = CGVectorMake(0, 0);
    
    if (!self.motionManager.accelerometerActive) {
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error){
            CGFloat x = accelerometerData.acceleration.x;
            CGFloat y = accelerometerData.acceleration.y;
            
            // interfaceOrientation deprecated
            switch ([[UIApplication sharedApplication] statusBarOrientation]) {
                case UIInterfaceOrientationPortrait:
                    self.gravity.gravityDirection = CGVectorMake(x, -y);
                    break;
                case UIInterfaceOrientationPortraitUpsideDown:
                    self.gravity.gravityDirection = CGVectorMake(-x, y);
                    break;
                case UIInterfaceOrientationLandscapeLeft:
                    self.gravity.gravityDirection = CGVectorMake(y, x);
                    break;
                case UIInterfaceOrientationLandscapeRight:
                    self.gravity.gravityDirection = CGVectorMake(-y, -x);
                    break;
                default:
                    break;
            }
            [self updateScore];
        }];
    }
}

- (void)pauseGame{
    [self.motionManager stopAccelerometerUpdates];
    self.gravity.gravityDirection = CGVectorMake(0, 0);
    self.quicksand.resistance = 10.0;
    [self pauseScoring];
}

- (void)restartGame{
    self.animator = nil;
    self.motionManager = nil;
    @autoreleasepool {
        [self.redBlock removeFromSuperview];
        [self.blackBlock removeFromSuperview];
    }
    [self resetScore];
    if(self.view.window) [self resumeGame];
}

- (void)resetElasticity{
    NSNumber *elasticity = [[NSUserDefaults standardUserDefaults] valueForKey:@"Settings_Elasticity"];
    if (elasticity) {
        self.elastic.elasticity = [elasticity floatValue];
    } else {
        self.elastic.elasticity = 1.0;
    }
}

#pragma mark - Score

- (void)updateScore{
    if (self.lastRecordedBlackBlockTravelTime) {
        self.cumulativeBlackBlockTravelTime -= [self.lastRecordedBlackBlockTravelTime timeIntervalSinceNow];
        double score = self.blackBlockDistanceTraveled / self.cumulativeBlackBlockTravelTime;
        if (score > self.maxScore) self.maxScore = score;
        if (score != self.lastScore || ![self.scoreLabel.text length]) {
            self.scoreLabel.textColor = [UIColor blackColor];
            self.scoreLabel.text = [NSString stringWithFormat:@"%.0f\n%.0f",score,self.maxScore];
            [self updateScoreBoundary];
        } else if(!CGPointEqualToPoint(self.scoreBoundaryCenter, self.scoreLabel.center)) {
            [self updateScoreBoundary];
        }
    } else {
        [self.animator addBehavior:self.blackBlockTracker];
        self.scoreLabel.text = nil;
    }
    self.lastRecordedBlackBlockTravelTime = [NSDate date];
}

- (void)pauseScoring{
    self.lastRecordedBlackBlockTravelTime = nil;
    self.scoreLabel.text = @"Paused";
    self.scoreLabel.textColor = [UIColor lightGrayColor];
    [self.animator removeBehavior:self.blackBlockTracker];
}

- (void)resetScore{
    self.blackBlockDistanceTraveled = 0;
    self.lastRecordedBlackBlockTravelTime = nil;
    self.cumulativeBlackBlockTravelTime = 0;
    self.maxScore = 0;
    self.lastScore = 0;
    self.scoreLabel.text = @"";
}

- (UILabel *)scoreLabel{
    if (!_scoreLabel) {
        UILabel *scoreLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
        scoreLabel.font = [scoreLabel.font fontWithSize:64];
        scoreLabel.textAlignment = NSTextAlignmentCenter;
        scoreLabel.numberOfLines = 2;
        scoreLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.view insertSubview:scoreLabel atIndex:0];
        _scoreLabel = scoreLabel;
    }
    return _scoreLabel;
}

- (UICollisionBehavior *)scoreBoundary{
    if (!_scoreBoundary) {
        UICollisionBehavior *scoreBoundary = [[UICollisionBehavior alloc] initWithItems:@[self.redBlock,self.blackBlock]];
        [self.animator addBehavior:scoreBoundary];
        _scoreBoundary = scoreBoundary;
    }
    return _scoreBoundary;
}

- (void)updateScoreBoundary{
    CGSize scoreSize = [self.scoreLabel.text sizeWithAttributes:@{ NSFontAttributeName: self.scoreLabel.font }];
    self.scoreBoundaryCenter = self.scoreLabel.center;
    CGRect scoreRect = CGRectMake(self.scoreBoundaryCenter.x - scoreSize.width/2,
                                  self.scoreBoundaryCenter.y - scoreSize.height/2,
                                  scoreSize.width,
                                  scoreSize.height);
    [self.scoreBoundary removeBoundaryWithIdentifier:@"Score"];
    [self.scoreBoundary addBoundaryWithIdentifier:@"Score"
                                          forPath:[UIBezierPath bezierPathWithRect:scoreRect]];
}

#pragma mark - BlackBlockTracker

- (UIDynamicItemBehavior *)blackBlockTracker{
    if (!_blackBlockTracker) {
        UIDynamicItemBehavior *blackBlockTracker = [[UIDynamicItemBehavior alloc] initWithItems:@[self.blackBlock]];
        [self.animator addBehavior:blackBlockTracker];
        __weak ViewController *weakSelf = self;
        __block CGPoint lastKnownBlackBlockCenter = self.blackBlock.center;
        blackBlockTracker.action = ^{
            CGFloat dx = weakSelf.blackBlock.center.x - lastKnownBlackBlockCenter.x;
            CGFloat dy = weakSelf.blackBlock.center.y - lastKnownBlackBlockCenter.y;
            weakSelf.blackBlockDistanceTraveled += sqrt(dx*dx+dy*dy);
            lastKnownBlackBlockCenter = weakSelf.blackBlock.center;
        };
        _blackBlockTracker = blackBlockTracker;
    }
    return _blackBlockTracker;
}

@end
