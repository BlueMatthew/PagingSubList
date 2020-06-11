//
//  WebviewCell.h
//  PagingSubList
//
//  Created by Matthew Shi on 2020/6/7.
//  Copyright © 2020 Matthew Shi. All rights reserved.
//

#ifndef WebviewCell_h
#define WebviewCell_h

#import <UIKit/UIKit.h>

@interface SUIWebViewCell : UICollectionViewCell

- (void)updateDataSource:(nullable NSMutableDictionary *)item;

@end

#endif /* WebviewCell_h */
