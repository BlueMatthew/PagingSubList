//
//  CollectionViewPagingLayout.mm
//  PagingSubList
//
//  Created by Matthew Shi on 2020/6/7.
//  Copyright © 2020 Matthew Shi. All rights reserved.
//

#import "CollectionViewPagingLayout.h"
#include <map>

@interface UICollectionViewPagingLayoutInvalidationContext : UICollectionViewFlowLayoutInvalidationContext
@property (nonatomic, assign) BOOL invalidateOffset; // Paging Or Sticky

@end

@implementation UICollectionViewPagingLayoutInvalidationContext

@end

@interface UICollectionViewPagingLayout()
{
    BOOL m_layoutInvalidated;
    
    std::map<NSInteger, BOOL> m_stickyHeaders; // Section Index -> Sticy Status
}

@end

@implementation UICollectionViewPagingLayout
@synthesize pagingOffset = m_pagingOffset;
@synthesize pagingSection = m_pagingSection;

- (instancetype)init
{
    if (self = [super init])
    {
        m_layoutInvalidated = YES;
        m_pagingSection = NSNotFound;
        m_pagingOffset = CGPointZero;
    }
    
    return self;
}

 - (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ([super initWithCoder:aDecoder])
    {
        m_layoutInvalidated = YES;
        m_pagingSection = [aDecoder containsValueForKey:@"pagingSection"] ? [aDecoder decodeIntegerForKey:@"pagingSection"] : NSNotFound;
        m_pagingOffset = [aDecoder containsValueForKey:@"pagingOffset"] ? [aDecoder decodeCGPointForKey:@"pagingOffset"] : CGPointZero;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];

    [aCoder encodeCGPoint:m_pagingOffset forKey:@"pagingOffset"];
    [aCoder encodeInteger:m_pagingSection forKey:@"pagingSection"];
}

+ (Class)invalidationContextClass
{
    return [UICollectionViewPagingLayoutInvalidationContext class];
}

- (void)setPagingSection:(NSInteger)pagingSection
{
    if (m_pagingSection != pagingSection)
    {
        m_pagingSection = pagingSection;
        [self invalidateLayout];    // ANY OPTIMIZATION?
    }
}

- (void)prepareLayout
{
    if (m_layoutInvalidated)
    {
        [super prepareLayout];
        m_layoutInvalidated = NO;
    }
}

- (void)invalidateOffset
{
    UICollectionViewPagingLayoutInvalidationContext *context = (UICollectionViewPagingLayoutInvalidationContext *)[[[UICollectionViewPagingLayout invalidationContextClass] alloc] init];
    context.invalidateOffset = YES;
    [self invalidateLayoutWithContext:context];
}

- (void)setPagingOffset:(CGPoint)pagingOffset
{
    m_pagingOffset = pagingOffset;
    
    if (m_pagingSection == NSNotFound)
    {
        return;
    }
    
    [self invalidateOffset];
}

- (void)addStickyHeader:(NSInteger)section
{
    if (m_stickyHeaders.find(section) == m_stickyHeaders.end())
    {
        m_stickyHeaders[section] = NO;
    }
    
    [self invalidateOffset];
}

- (void)removeAllStickyHeaders
{
    m_stickyHeaders.clear();
    
    [self invalidateOffset];
}

- (void)invalidateLayout
{
    [super invalidateLayout];
    
    m_layoutInvalidated = YES;
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context
{
    [super invalidateLayoutWithContext:context];
    
    if ([context isKindOfClass:[UICollectionViewPagingLayout invalidationContextClass]])
    {
        UICollectionViewPagingLayoutInvalidationContext *pagingInvalidationContext = (UICollectionViewPagingLayoutInvalidationContext *)context;
        if (!pagingInvalidationContext.invalidateOffset)
        {
            // It is not caused by internal offset change, should call prepareLayout
            m_layoutInvalidated = YES;
        }
    }
    else
    {
        // It is not caused by offset change, should call prepareLayout
        m_layoutInvalidated = YES;
    }
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSArray<UICollectionViewLayoutAttributes *> *layoutAttributesArray = [super layoutAttributesForElementsInRect:rect];
    NSMutableArray<UICollectionViewLayoutAttributes *> *newLayoutAttributesArray = [[NSMutableArray<UICollectionViewLayoutAttributes *> alloc] initWithCapacity:4];

    if (!m_stickyHeaders.empty())
    {
        NSInteger maxSection = NSIntegerMin;
        // NSInteger minSection = NSIntegerMax;
        std::map<NSInteger, UICollectionViewLayoutAttributes *> headerLayoutAttributesMap;
        
        for (UICollectionViewLayoutAttributes *layoutAttributes in layoutAttributesArray)
        {
            if (m_stickyHeaders.find(layoutAttributes.indexPath.section) != m_stickyHeaders.end())
            {
                if ([layoutAttributes.representedElementKind isEqualToString:UICollectionElementKindSectionHeader])
                {
                    headerLayoutAttributesMap[layoutAttributes.indexPath.section] = layoutAttributes;
                }
            }
            if (layoutAttributes.representedElementCategory == UICollectionElementCategoryCell)
            {
                if (layoutAttributes.indexPath.section > maxSection)
                {
                    maxSection = layoutAttributes.indexPath.section;
                }
                // if (layoutAttributes.indexPath.section < minSection)
                // {
                //     minSection = layoutAttributes.indexPath.section;
                // }
            }
        }

        CGPoint contentOffset = self.collectionView.contentOffset;
        UIEdgeInsets contentInset = self.collectionView.contentInset;
        CGFloat totalHeaderHeight = 0;
        
        for (std::map<NSInteger, BOOL>::iterator it = m_stickyHeaders.begin(); it != m_stickyHeaders.end(); ++it)
        {
            if (it->first > maxSection)
            {
                it->second = NO;
                continue;
            }
            
            UICollectionViewLayoutAttributes *layoutAttributes = nil;
            
            std::map<NSInteger, UICollectionViewLayoutAttributes *>::const_iterator itHeaderLayoutAttributes = headerLayoutAttributesMap.find(it->first);
            if (itHeaderLayoutAttributes == headerLayoutAttributesMap.end())
            {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:it->first];
                layoutAttributes = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
                if (CGSizeEqualToSize(layoutAttributes.size, CGSizeZero))
                {
                    continue;
                }
                
                [newLayoutAttributesArray addObject:layoutAttributes];
            }
            else
            {
                layoutAttributes = itHeaderLayoutAttributes->second;
            }
            
            CGFloat headerHeight = CGRectGetHeight(layoutAttributes.frame);
            CGPoint origin = layoutAttributes.frame.origin;
            CGPoint oldOrigin = origin;
            
            origin.y = MAX(contentOffset.y + totalHeaderHeight + contentInset.top, origin.y);
            
            layoutAttributes.frame = (CGRect){ .origin = CGPointMake(origin.x, origin.y), .size = layoutAttributes.frame.size };
           
            // If original mode is sticky, we check contentOffset and if contentOffset.y is less than origin.y, it is exiting sticky mode
            // Otherwise, we check the top of sticky header
            BOOL stickyMode = it->second ? ((contentOffset.y + contentInset.top < oldOrigin.y) ? NO : YES) : ((layoutAttributes.frame.origin.y > oldOrigin.y) ? YES : NO);
           
            if (stickyMode != it->second)
            {
                // Notify caller if changed
                it->second = stickyMode;
                stickyMode ? [self enterStickyModeAt:it->first withOriginalPoint:oldOrigin] : [self exitStickyModeAt:it->first];
            }
            
            layoutAttributes.zIndex = 1024 + it->first;  //
            
            totalHeaderHeight += headerHeight;
        }
    }

    // PagingOffset
    if (m_pagingSection != NSNotFound && !CGPointEqualToPoint(m_pagingOffset, CGPointZero))
    {
        for (UICollectionViewLayoutAttributes *layoutAttributes in layoutAttributesArray)
        {
            if (layoutAttributes.indexPath.section >= m_pagingSection)
            {
                layoutAttributes.frame = CGRectOffset(layoutAttributes.frame, m_pagingOffset.x, m_pagingOffset.y);
            }
        }
        for (UICollectionViewLayoutAttributes *layoutAttributes in newLayoutAttributesArray)
        {
            if (layoutAttributes.indexPath.section >= m_pagingSection)
            {
                layoutAttributes.frame = CGRectOffset(layoutAttributes.frame, m_pagingOffset.x, m_pagingOffset.y);
            }
        }
    }
    
    return (nil == layoutAttributesArray) ? newLayoutAttributesArray : (newLayoutAttributesArray.count > 0 ? [layoutAttributesArray arrayByAddingObjectsFromArray:newLayoutAttributesArray] : layoutAttributesArray);
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    if (!m_stickyHeaders.empty())
    {
        // Don't return YES because it will call invalidateLayout
        [self invalidateOffset];
    }
    
    return [super shouldInvalidateLayoutForBoundsChange:newBounds];
}

- (void)enterStickyModeAt:(NSInteger)section withOriginalPoint:(CGPoint)point
{
    if ([self.collectionView.delegate conformsToProtocol:@protocol(UICollectionViewPagingLayoutDelegate)] && [self.collectionView.delegate respondsToSelector:@selector(collectionView:layout:headerEnterStickyModeAtSection:withOriginalPoint:)])
    {
        [((id<UICollectionViewPagingLayoutDelegate>)self.collectionView.delegate) collectionView:self.collectionView layout:self headerEnterStickyModeAtSection:section withOriginalPoint:point];
    }
}

- (void)exitStickyModeAt:(NSInteger)section
{
    if ([self.collectionView.delegate conformsToProtocol:@protocol(UICollectionViewPagingLayoutDelegate)] && [self.collectionView.delegate respondsToSelector:@selector(collectionView:layout:headerExitStickyModeAtSection:)])
    {
        [((id<UICollectionViewPagingLayoutDelegate>)self.collectionView.delegate) collectionView:self.collectionView layout:self headerExitStickyModeAtSection:section];
    }
}


@end
