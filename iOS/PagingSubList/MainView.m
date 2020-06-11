//
//  MainView.m
//  PagingSubList
//
//  Created by Matthew Shi on 2020/6/7.
//  Copyright © 2020 Matthew Shi. All rights reserved.
//

#import "MainView.h"
#import "PagingListView.h"
#import "UIUtility.h"

#define HEIGHT_NAVBAR             100
#define BGCOLOR_NAVBAR            0xFF7F50   // coral

@implementation SUIMainView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        CGRect frameNavBar = CGRectMake(0, 0, CGRectGetWidth(frame), HEIGHT_NAVBAR);
        UIView *navbarView = [[UIView alloc] initWithFrame:frameNavBar];
        navbarView.backgroundColor = UIColorFromRGB(BGCOLOR_NAVBAR);
        [self addSubview:navbarView];
        
        UILabel *navbarTitleLabel = [[UILabel alloc] initWithFrame:navbarView.bounds];
        navbarTitleLabel.text = @"Navigation Bar";
        [navbarView addSubview:navbarTitleLabel];
        
        CGRect frameListView = CGRectMake(0, HEIGHT_NAVBAR, CGRectGetWidth(frame), CGRectGetHeight(frame) - HEIGHT_NAVBAR);
        SUIPagingListView *listView = [[SUIPagingListView alloc] initWithFrame:frameListView];
        [self addSubview:listView];
    }
    
    return self;
}

@end
