//
//  PagingCollectionView.m
//  PagingSubList
//
//  Created by Matthew Shi on 2020/6/6.
//  Copyright © 2020 Matthew Shi. All rights reserved.
//

#import "PagingCollectionView.h"
#import "TimerAnimation.h"

static const NSTimeInterval UIScrollViewAnimationDuration = 0.33;
// static const NSTimeInterval UIScrollViewQuickAnimationDuration = 0.22;

@interface UIPagingContext : NSObject

@property (nonatomic, assign) NSInteger page;
@property (nonatomic, assign) NSInteger pageSize;
@property (nonatomic, assign) NSInteger section;
@property (nonatomic, assign) BOOL  leftOrRight;
@property (nonatomic, assign) CGPoint offset;

- (nullable instancetype)initWithPage:(NSInteger)page size:(NSInteger)pageSize;

@end

@implementation UIPagingContext
@synthesize page = m_page;
@synthesize pageSize = m_pageSize;

- (nullable instancetype)initWithPage:(NSInteger)page size:(NSInteger)pageSize
{
    if (self = [super init])
    {
        m_page = page;
        m_pageSize = pageSize;
    }
    
    return self;
}

@end

@interface UIPagingCollectionView() <UIGestureRecognizerDelegate>
{
    UIPanGestureRecognizer                      *m_swipeGuestureRecognizer;
    UICollectionViewScrollDirection             m_swipeDirection;
    UIPagingContext                             *m_pagingContext;

    UIView                                      *m_leftView;
    UIView                                      *m_rightView;
    CGRect                                      m_originalLeftFrame;
    CGRect                                      m_originalRightFrame;
    
    NSPointerArray                              *m_pagingAnimators;
}

@end

@implementation UIPagingCollectionView
@synthesize pagingDelegate = m_pagingDelegate;

- (void)dealloc
{
    if (nil != m_pagingAnimators)
    {
        NSArray *animators = [m_pagingAnimators allObjects];
        for (NSObject *obj in animators)
        {
            if ([obj isKindOfClass:[TimerAnimation class]])
            {
                TimerAnimation *animator = (TimerAnimation *)obj;
                [animator invalidate];
            }
        }
        animators = nil;
        m_pagingAnimators = nil;
    }

    if (nil != m_swipeGuestureRecognizer)
    {
        [self removeGestureRecognizer:m_swipeGuestureRecognizer];
        m_swipeGuestureRecognizer.delegate = nil;
        m_swipeGuestureRecognizer = nil;
    }
}

- (id<UIPagingCollectionViewDelegate>)pagingDelegate
{
    return m_pagingDelegate;
}

- (void)setPagingDelegate:(id<UIPagingCollectionViewDelegate>)pagingDelegate
{
    m_pagingDelegate = pagingDelegate;
}

- (void)enablePagingWithDirection:(UICollectionViewScrollDirection)direction
{
    if (nil == m_swipeGuestureRecognizer)
    {
        m_swipeGuestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
        m_swipeGuestureRecognizer.delegate = self;
        [self addGestureRecognizer:m_swipeGuestureRecognizer];
    }
    m_swipeDirection = direction;
}

- (void)disablePaging
{
    if (nil != m_swipeGuestureRecognizer)
    {
        [self removeGestureRecognizer:m_swipeGuestureRecognizer];
        m_swipeGuestureRecognizer.delegate = nil;
        m_swipeGuestureRecognizer = nil;
    }
}

- (void)offsetPagingViews:(CGPoint)offset
{
    if (nil != m_leftView)
    {
        m_leftView.frame = CGRectOffset(m_originalLeftFrame, offset.x, offset.y);
    }
    if (nil != m_rightView)
    {
        m_rightView.frame = CGRectOffset(m_originalRightFrame, offset.x, offset.y);
    }
}


- (void)cleanPagingViews
{
    [UIView performWithoutAnimation:^{
        if (nil != self->m_leftView)
        {
            self->m_leftView.frame = self->m_originalLeftFrame;
            [self->m_leftView removeFromSuperview];
            self->m_leftView = nil;
        }
        if (nil != self->m_rightView)
        {
            self->m_rightView.frame = self->m_originalRightFrame;
            [self->m_rightView removeFromSuperview];
            self->m_rightView = nil;
        }
    }];
}

- (CGPoint)calcTargetPoint:(CGPoint)point withVelocity:(CGPoint)velocity decelerationRate:(CGFloat)decelerationRate
{
    // https://developer.apple.com/videos/play/wwdc2018/803/
    // Distance travelled after decelerating to zero velocity at a constant rate.
    // func project(initialVelocity: Float, decelerationRate: Float) -> Float {
    //    return (initialVelocity / 1000.0) * decelerationRate / (1.0 - decelerationRate)
    // }
    
    return CGPointMake(point.x + (velocity.x / 1000.0) * decelerationRate / (1.0 - decelerationRate),
                       point.y + (velocity.y / 1000.0) * decelerationRate / (1.0 - decelerationRate));
}

- (void)handleSwipe:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == m_swipeGuestureRecognizer)
    {
        switch(m_swipeGuestureRecognizer.state)
        {
            case UIGestureRecognizerStateBegan:
            {
                CGPoint location =[m_swipeGuestureRecognizer locationInView:self];
                CGPoint translation =[m_swipeGuestureRecognizer translationInView:self];
                CGPoint velocity =[m_swipeGuestureRecognizer velocityInView:self];
                
                BOOL shouldBegin = NO;
                NSInteger section = NSNotFound;
                if ([self.pagingDelegate collectionView:self pagingShouldBeginAtLocation:location withTranslation:translation andVelocity:velocity onSection:&section])
                {
                    shouldBegin = YES;
                }
                
                m_pagingContext = nil;
                if (shouldBegin)
                {
                    NSInteger page = [m_pagingDelegate pageForSection:section inPagingCollectionView:self];
                    NSInteger pageSize = [m_pagingDelegate pageSizeForSection:section inPagingCollectionView:self];
                    
                    m_pagingContext = [[UIPagingContext alloc] initWithPage:page size:pageSize];
                    m_pagingContext.section = section;
                    
                    // m_swipingContext.leftOrRight = (translation.x < 0);
                    m_pagingContext.leftOrRight = ((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) && (velocity.x < 0)) || ((m_swipeDirection == UICollectionViewScrollDirectionVertical) && (velocity.y < 0));
                    
                    [self buildViewForPage:m_pagingContext];
                    
                    CGPoint offset = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? CGPointMake(translation.x, 0) : CGPointMake(0, translation.y);
                    [self pagingWithOffset:offset decelerating:NO onPagingContext:m_pagingContext andBindingPagingViews:YES];
                }
            }
                break;
            case UIGestureRecognizerStateChanged:
            {
                if (nil != m_pagingContext)
                {
                    CGPoint translation = [m_swipeGuestureRecognizer translationInView:self];
                    
                    if (((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) && (translation.x == 0)) || ((m_swipeDirection == UICollectionViewScrollDirectionVertical) && (translation.y == 0)))
                    {
                        // NO Movement, everything is as same as old, DO NOTHING
                    }
                    else
                    {
                        m_pagingContext.leftOrRight = ((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) && (translation.x < 0)) || ((m_swipeDirection == UICollectionViewScrollDirectionVertical) && (translation.y < 0));
                        
                        [self buildViewForPage:m_pagingContext];
                    }
                    
                    CGPoint offset = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? CGPointMake(translation.x, 0) : CGPointMake(0, translation.y);
                    [self pagingWithOffset:offset decelerating:NO onPagingContext:m_pagingContext andBindingPagingViews:YES];
                }
            }
                break;
            case UIGestureRecognizerStateEnded:
            {
                if (nil != m_pagingContext)
                {
                    CGPoint translation = [m_swipeGuestureRecognizer translationInView:self];
                    
                    CGPoint offset = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? CGPointMake(translation.x, 0) : CGPointMake(0, translation.y);
                    [self pagingWithOffset:offset decelerating:NO onPagingContext:m_pagingContext andBindingPagingViews:YES];
                    
                    if (((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) && (translation.x == 0)) || ((m_swipeDirection == UICollectionViewScrollDirectionVertical) && (translation.y == 0)))
                    {
                        // NO Movement, everything is as same as old, DO NOTHING
                        [self cleanPagingViews];
                        break;
                    }
                    
                    m_pagingContext.leftOrRight = ((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) && (translation.x < 0)) || ((m_swipeDirection == UICollectionViewScrollDirectionVertical) && (translation.y < 0));
                    
                    CGPoint targetOffset = CGPointZero;
                    BOOL decelerationAnimation = YES;
                    
                    __block NSInteger newPage = m_pagingContext.leftOrRight ? (m_pagingContext.page + 1) : (m_pagingContext.page - 1);
                    if (newPage >= 0 && newPage < m_pagingContext.pageSize)
                    {
                        CGFloat totalSize = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? self.bounds.size.width : self.bounds.size.height;
                        CGFloat halfSize = totalSize / 2;
                        // Go back to original position without page change
                        // no valid page
                        CGFloat absTranslation = fabs((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? translation.x : translation.y);
                        BOOL overHalfSize = YES;
                        if (absTranslation == totalSize)
                        {
                            // Dragging distance DOES equal one page size exactly, no any deceleration animation more.
                            decelerationAnimation = NO;
                        }
                        // else if (absTranslation >= halfSize) {}
                        else if (absTranslation < halfSize)
                        {
                            // Calculate deceleration distance
                            CGPoint velocity = [m_swipeGuestureRecognizer velocityInView:self];
                            CGPoint decelerationTargetPoint = [self calcTargetPoint:translation withVelocity:velocity decelerationRate:UIScrollViewDecelerationRateNormal];
                            CGFloat finalDistance = fabs((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? (decelerationTargetPoint.x) : decelerationTargetPoint.y);
                            if (finalDistance < halfSize)
                            {
                                overHalfSize = NO;
                                // Restore orginal page
                                newPage = m_pagingContext.page;
                            }
                        }
                        
                        if (decelerationAnimation && overHalfSize)
                        {
                            CGFloat targetTotalOffset = m_pagingContext.leftOrRight ? (-totalSize) : totalSize;
                            targetOffset = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? CGPointMake(targetTotalOffset, 0) : CGPointMake(0, targetTotalOffset);
                        }
                    }
                    else // NO More page
                    {
                        newPage = m_pagingContext.page;
                    }
                    
                    if (decelerationAnimation)
                    {
                        __block UIPagingContext *swipeContext = m_pagingContext;
                        __block UICollectionViewScrollDirection swipeDirection = m_swipeDirection;
                        
                        __block BOOL userInteractionEnabled = self.userInteractionEnabled;
                        self.userInteractionEnabled = NO;
                        
                        __block CGFloat startValue = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? translation.x : translation.y;
                        __block CGFloat endValue = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? targetOffset.x : targetOffset.y;
                        __block CGFloat decelerationRate = UIScrollViewDecelerationRateNormal;
                        
                        TimerAnimation *timerAnimation = [[TimerAnimation alloc] initWithDuration:UIScrollViewAnimationDuration animations:^(CGFloat progress) {
                            CGFloat value = startValue + (1 - powf((1 - progress), decelerationRate)) * (endValue - startValue);
                            CGPoint offset = (swipeDirection == UICollectionViewScrollDirectionHorizontal) ?  CGPointMake(value, 0) : CGPointMake(0, value);
                            [self pagingWithOffset:offset decelerating:YES onPagingContext:swipeContext andBindingPagingViews:YES];
                        } completion:^(BOOL finished) {
                            self.userInteractionEnabled = userInteractionEnabled;
                            
                            BOOL cleanPagingViews = YES;
                            if (newPage != swipeContext.page)
                            {
                                cleanPagingViews = [self->m_pagingDelegate collectionView:self pagingEndedOnSection:swipeContext.section toNewPage:newPage];
                            }

                            if (cleanPagingViews)
                            {
                                [self cleanPagingViews];
                            }
                        }];
                        
                        if (nil == m_pagingAnimators)
                        {
                            m_pagingAnimators = [NSPointerArray weakObjectsPointerArray];
                        }
                        [m_pagingAnimators addPointer:(__bridge void * _Nullable)timerAnimation];
                        
                    }
                    else
                    {
                        BOOL cleanPagingViews = YES;
                        // Completion with page change
                        if (newPage != m_pagingContext.page)
                        {
                            cleanPagingViews = [m_pagingDelegate collectionView:self pagingEndedOnSection:m_pagingContext.section toNewPage:newPage];
                        }
                        
                        if (cleanPagingViews)
                        {
                            [self cleanPagingViews];
                        }
                    }
                    
                    m_pagingContext = nil;
                }
            }
                break;
            default:
                break;
        }
    }
}

- (void)pagingWithOffset:(CGPoint)offset decelerating:(BOOL)decelerating onPagingContext:(UIPagingContext *)pagingContext andBindingPagingViews:(BOOL)bindingPagingViews
{
    if (CGPointEqualToPoint(offset, pagingContext.offset))
    {
        return;
    }
    
    pagingContext.offset = offset;
    
    if ([m_pagingDelegate conformsToProtocol:@protocol(UIPagingCollectionViewDelegate)] && [m_pagingDelegate respondsToSelector:@selector(collectionView:pagingWithOffset:decelerating:onSection:)])
    {
        [self.pagingDelegate collectionView:self pagingWithOffset:offset decelerating:decelerating onSection:pagingContext.section];
    }
    
    if (bindingPagingViews)
    {
        [UIView performWithoutAnimation:^{
            if (nil != self->m_leftView)
            {
                self->m_leftView.frame = CGRectOffset(self->m_originalLeftFrame, offset.x, offset.y);
            }
            if (nil != self->m_rightView)
            {
                self->m_rightView.frame = CGRectOffset(self->m_originalRightFrame, offset.x, offset.y);
            }
        }];
    }
}

- (void)buildViewForPage:(UIPagingContext *)pageContext
{
    UIView * __strong *pView = pageContext.leftOrRight ? (&m_leftView) : (&m_rightView);
    if (nil != *pView)
    {
        return;
    }
    CGRect * pOriginalFrame = pageContext.leftOrRight ? (&m_originalLeftFrame) : (&m_originalRightFrame);
    
    NSInteger newPage = pageContext.leftOrRight ? (pageContext.page + 1) : (pageContext.page - 1);
    if (newPage < 0 || newPage >= pageContext.pageSize)
    {
        return;
    }
    
    UIView *view = [self.pagingDelegate pagingCollectionView:self viewForPage:newPage inSection:pageContext.section];
    CGFloat xOffset = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? (pageContext.leftOrRight ? self.bounds.size.width : -self.bounds.size.width) : 0;
    CGFloat yOffset = (m_swipeDirection == UICollectionViewScrollDirectionHorizontal) ? 0 : (pageContext.leftOrRight ? self.bounds.size.height : -self.bounds.size.height);
    view.frame = CGRectOffset(view.frame, xOffset, yOffset);
    *pOriginalFrame = view.frame;

    *pView = view;
    
    [self addSubview:view];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == m_swipeGuestureRecognizer)
    {
        CGPoint location =[m_swipeGuestureRecognizer locationInView:self];
        CGPoint velocity =[m_swipeGuestureRecognizer velocityInView:self];
        CGPoint translation =[m_swipeGuestureRecognizer translationInView:self];
        
        BOOL shouldBegin = NO;
        NSInteger section = NSNotFound;
        // Check direction first
        if (((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) && (fabs(velocity.x) > fabs(velocity.y))) || ((m_swipeDirection == UICollectionViewScrollDirectionVertical) && (fabs(velocity.y) > fabs(velocity.x))))
        {
            if ([self.pagingDelegate collectionView:self pagingShouldBeginAtLocation:location withTranslation:translation andVelocity:velocity onSection:&section])
            {
                shouldBegin = YES;
            }
        }
        
        if (shouldBegin)
        {
            NSInteger page = [m_pagingDelegate pageForSection:section inPagingCollectionView:self];
            NSInteger pageSize = [m_pagingDelegate pageSizeForSection:section inPagingCollectionView:self];
            
            UIPagingContext *pageContext = [[UIPagingContext alloc] initWithPage:page size:pageSize];
            
            pageContext.leftOrRight = ((m_swipeDirection == UICollectionViewScrollDirectionHorizontal) && (velocity.x < 0)) || ((m_swipeDirection == UICollectionViewScrollDirectionVertical) && (velocity.y < 0));
            pageContext.section = section;
            
            // async action
            [self performSelector:@selector(buildViewForPage:) withObject:pageContext afterDelay:0];
        }
        
        return shouldBegin;
    }
    
    return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(nonnull UIGestureRecognizer *)otherGestureRecognizer
{
    /*:
     For more information, see [Preferring One Gesture Over Another](https://developer.apple.com/documentation/uikit/touches_presses_and_gestures/coordinating_multiple_gesture_recognizers/preferring_one_gesture_over_another)
     */
    // Do not begin the pan until the swipe fails.
    if ((gestureRecognizer == m_swipeGuestureRecognizer) &&
        (otherGestureRecognizer == self.panGestureRecognizer))
    {
        return YES;
    }
    
    return NO;
}

@end
