//
//  FXBlurView.m
//
//  Version 1.4.4
//
//  Created by Nick Lockwood on 25/08/2013.
//  Copyright (c) 2013 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXBlurView
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

//
//  Forked by iwill on 2013-12-03.
//  https://github.com/iwill/FXBlurView
//


#import "FXBlurView.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>

#import "UIImage+ImageEffects.h"


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


#define OR ? :


@interface FXBlurScheduler : NSObject

@property (nonatomic, strong) NSMutableArray *views;
@property (nonatomic, assign) NSInteger viewIndex;
@property (nonatomic, assign) NSInteger updatesEnabled;
@property (nonatomic, assign) BOOL blurEnabled;
@property (nonatomic, assign) BOOL updating;

@end


@interface FXBlurView ()

@property (nonatomic, assign) BOOL blurRadiusSet;
@property (nonatomic, assign) BOOL dynamicSet;
@property (nonatomic, assign) BOOL blurEnabledSet;
@property (nonatomic, strong) NSDate *lastUpdate;

- (UIImage *)snapshotOfSuperview:(UIView *)superview;

@end


@implementation FXBlurScheduler

+ (instancetype)sharedInstance
{
    static FXBlurScheduler *sharedInstance = nil;
    if (!sharedInstance)
    {
        sharedInstance = [[FXBlurScheduler alloc] init];
    }
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init])
    {
        _updatesEnabled = 1;
        _blurEnabled = YES;
        _views = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setBlurEnabled:(BOOL)blurEnabled
{
    _blurEnabled = blurEnabled;
    if (blurEnabled)
    {
        for (FXBlurView *view in self.views)
        {
            [view setNeedsDisplay];
        }
        [self updateAsynchronously];
    }
}

- (void)setUpdatesEnabled
{
    _updatesEnabled ++;
    [self updateAsynchronously];
}

- (void)setUpdatesDisabled
{
    _updatesEnabled --;
}

- (void)addView:(FXBlurView *)view
{
    if (![self.views containsObject:view])
    {
        [self.views addObject:view];
        [self updateAsynchronously];
    }
}

- (void)removeView:(FXBlurView *)view
{
    NSInteger index = [self.views indexOfObject:view];
    if (index != NSNotFound)
    {
        if (index <= self.viewIndex)
        {
            self.viewIndex --;
        }
        [self.views removeObjectAtIndex:index];
    }
}

- (void)updateAsynchronously
{
    if (self.blurEnabled && !self.updating && self.updatesEnabled > 0 && [self.views count])
    {
        //loop through until we find a view that's ready to be drawn
        self.viewIndex = self.viewIndex % [self.views count];
        for (NSUInteger i = self.viewIndex; i < [self.views count]; i++)
        {
            FXBlurView *view = self.views[i];
            if (view.blurEnabled && view.dynamic && view.window &&
                (!view.lastUpdate || [view.lastUpdate timeIntervalSinceNow] < -view.updateInterval) &&
                !CGRectIsEmpty(view.bounds) && !CGRectIsEmpty(view.superview.bounds))
            {
                self.updating = YES;
                UIImage *snapshot = [view snapshotOfSuperview:view.superview];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    
                    UIImage *blurredImage = [snapshot applyBlurWithRadius:view.blurRadius
                                                                tintColor:view.tintColor
                                                    saturationDeltaFactor:view.saturationDeltaFactor
                                                                maskImage:nil];
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        
                        //set image
                        self.updating = NO;
                        if (view.dynamic)
                        {
                            view.layer.contents = (id)blurredImage.CGImage;
                            view.layer.contentsScale = blurredImage.scale;
                        }
                        
                        //render next view
                        self.viewIndex = i + 1;
                        [self performSelectorOnMainThread:@selector(updateAsynchronously) withObject:nil
                                            waitUntilDone:NO modes:@[NSDefaultRunLoopMode, UITrackingRunLoopMode]];
                    });
                });
                return;
            }
        }
        
        //try again
        self.viewIndex = 0;
        [self performSelectorOnMainThread:@selector(updateAsynchronously) withObject:nil
                            waitUntilDone:NO modes:@[NSDefaultRunLoopMode, UITrackingRunLoopMode]];
    }
}

@end


@implementation FXBlurView

+ (void)setBlurEnabled:(BOOL)blurEnabled
{
    [FXBlurScheduler sharedInstance].blurEnabled = blurEnabled;
}

+ (void)setUpdatesEnabled
{
    [[FXBlurScheduler sharedInstance] setUpdatesEnabled];
}

+ (void)setUpdatesDisabled
{
    [[FXBlurScheduler sharedInstance] setUpdatesDisabled];
}

- (void)setUp
{
    if (!_blurRadiusSet) _blurRadius = 40.0f;
    if (!_dynamicSet) _dynamic = YES;
    if (!_blurEnabledSet) _blurEnabled = YES;
    self.updateInterval = _updateInterval;
    self.layer.magnificationFilter = @"linear"; //kCAFilterLinear;
    
    unsigned int numberOfMethods;
    Method *methods = class_copyMethodList([UIView class], &numberOfMethods);
    for (unsigned int i = 0; i < numberOfMethods; i++)
    {
        Method method = methods[i];
        SEL selector = method_getName(method);
        if (selector == @selector(tintColor))
        {
            _tintColor = ((id (*)(id,SEL))method_getImplementation(method))(self, selector);
            break;
        }
    }
    free(methods);
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setUp];
        self.clipsToBounds = YES;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setBlurRadius:(CGFloat)blurRadius
{
    _blurRadiusSet = YES;
    _blurRadius = blurRadius;
    [self setNeedsDisplay];
}

- (void)setBlurEnabled:(BOOL)blurEnabled
{
    _blurEnabledSet = YES;
    if (_blurEnabled != blurEnabled)
    {
        _blurEnabled = blurEnabled;
        [self schedule];
        if (_blurEnabled)
        {
            [self setNeedsDisplay];
        }
    }
}

- (void)setDynamic:(BOOL)dynamic
{
    _dynamicSet = YES;
    if (_dynamic != dynamic)
    {
        _dynamic = dynamic;
        [self schedule];
        if (!dynamic)
        {
            [self setNeedsDisplay];
        }
    }
}

- (void)setUpdateInterval:(NSTimeInterval)updateInterval
{
    _updateInterval = updateInterval;
    if (_updateInterval <= 0) _updateInterval = 1.0/60;
}

- (void)setTintColor:(UIColor *)tintColor
{
    _tintColor = tintColor;
    [self setNeedsDisplay];
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    [self.layer setNeedsDisplay];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self schedule];
}

- (void)schedule
{
    if (self.window && self.dynamic && self.blurEnabled)
    {
        [[FXBlurScheduler sharedInstance] addView:self];
    }
    else
    {
        [[FXBlurScheduler sharedInstance] removeView:self];
    }
}

- (void)setNeedsDisplay
{
    [super setNeedsDisplay];
    [self.layer setNeedsDisplay];
}

- (void)displayLayer:(__unused CALayer *)layer
{
    if ([FXBlurScheduler sharedInstance].blurEnabled && self.blurEnabled && self.superview &&
        !CGRectIsEmpty(self.bounds) && !CGRectIsEmpty(self.superview.bounds))
    {
        UIImage *snapshot = [self snapshotOfSuperview:self.superview];
        UIImage *blurredImage = [snapshot applyBlurWithRadius:self.blurRadius
                                                    tintColor:self.tintColor
                                        saturationDeltaFactor:self.saturationDeltaFactor
                                                    maskImage:nil];
        self.layer.contents = (id)blurredImage.CGImage;
        self.layer.contentsScale = blurredImage.scale;
    }
}

- (UIImage *)snapshotOfSuperview:(UIView *)superview
{
    self.lastUpdate = [NSDate date];
    CGFloat scale = 0.5;
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, -self.frame.origin.x, -self.frame.origin.y);
    NSArray *hiddenViews = [self prepareSuperviewForSnapshot:superview];
    [superview.layer renderInContext:context];
    [self restoreSuperviewAfterSnapshot:hiddenViews];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return snapshot;
}

- (NSArray *)prepareSuperviewForSnapshot:(UIView *)superview
{
    NSMutableArray *views = [NSMutableArray array];
    NSInteger index = [superview.subviews indexOfObject:self];
    if (index != NSNotFound)
    {
        for (NSUInteger i = index; i < [superview.subviews count]; i++)
        {
            UIView *view = superview.subviews[i];
            if (!view.hidden)
            {
                view.hidden = YES;
                [views addObject:view];
            }
        }
    }
    return views;
}

- (void)restoreSuperviewAfterSnapshot:(NSArray *)hiddenViews
{
    for (UIView *view in hiddenViews)
    {
        view.hidden = NO;
    }
}

- (void)setupLightEffect
{
    [self setupLightEffectWithColor:nil];
}

- (void)setupExtraLightEffect
{
    [self setupExtraLightEffectWithColor:nil];
}

- (void)setupDarkEffect
{
    [self setupDarkEffectWithColor:nil];
}

- (void)setupLightEffectWithColor:(UIColor *)tintColor
{
    CGFloat alpha = 0.3;
    self.blurRadius = 30;
    self.tintColor = [tintColor colorWithAlphaComponent:alpha] OR [UIColor colorWithWhite:1.0 alpha:alpha];
    self.saturationDeltaFactor = 1.8;
}

- (void)setupExtraLightEffectWithColor:(UIColor *)tintColor
{
    CGFloat alpha = 0.82;
    self.blurRadius = 20;
    self.tintColor = [tintColor colorWithAlphaComponent:alpha] OR [UIColor colorWithWhite:0.97 alpha:alpha];
    self.saturationDeltaFactor = 1.8;
}

- (void)setupDarkEffectWithColor:(UIColor *)tintColor
{
    CGFloat alpha = 0.73;
    self.blurRadius = 20;
    self.tintColor = [tintColor colorWithAlphaComponent:alpha] OR [UIColor colorWithWhite:0.11 alpha:alpha];
    self.saturationDeltaFactor = 1.8;
}

- (void)setupTintEffectWithColor:(UIColor *)tintColor
{
    const CGFloat EffectColorAlpha = 0.6;
    UIColor *effectColor = tintColor;
    int componentCount = CGColorGetNumberOfComponents(tintColor.CGColor);
    if (componentCount == 2) {
        CGFloat b;
        if ([tintColor getWhite:&b alpha:NULL]) {
            effectColor = [UIColor colorWithWhite:b alpha:EffectColorAlpha];
        }
    }
    else {
        CGFloat r, g, b;
        if ([tintColor getRed:&r green:&g blue:&b alpha:NULL]) {
            effectColor = [UIColor colorWithRed:r green:g blue:b alpha:EffectColorAlpha];
        }
    }
    
    self.blurRadius = 10;
    self.tintColor = effectColor;
    self.saturationDeltaFactor = - 1.0;
}

@end

