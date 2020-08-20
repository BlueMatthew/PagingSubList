//
//  CollectionViewPagingLayout.h
//  PagingSubList
//
//  Created by Matthew Shi on 2020/6/7.
//  Copyright © 2020 Matthew Shi. All rights reserved.
//

#ifndef CollectionViewPagingLayout_h
#define CollectionViewPagingLayout_h

#import <UIKit/UIKit.h>

// UICollectionViewPagingLayout: Layout With Paging and StickyHeader

@class UICollectionViewPagingLayout;

@protocol UICollectionViewPagingLayoutDelegate <UICollectionViewDelegateFlowLayout>

- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewPagingLayout *)layout headerEnterStickyModeAtSection:(NSInteger)section withOriginalPoint:(CGPoint)point;
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewPagingLayout *)layout headerExitStickyModeAtSection:(NSInteger)section;

@end

@interface UICollectionViewPagingLayout : UICollectionViewFlowLayout

@property (nonatomic, assign) NSInteger pagingSection;
@property (nonatomic, assign) CGPoint pagingOffset;

- (void)addStickyHeader:(NSInteger)section;
- (void)removeAllStickyHeaders;

@end

#endif /* CollectionViewPagingLayout_h */
