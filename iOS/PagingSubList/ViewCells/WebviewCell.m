//
//  WebviewCell.m
//  PagingSubList
//
//  Created by Matthew Shi on 2020/6/7.
//  Copyright © 2020 Matthew Shi. All rights reserved.
//

#import "WebviewCell.h"
#import <WebKit/WebKit.h>


@interface SUIWebViewCell()
{
    WKWebView   *m_view;
    NSString    *m_url;
}

@end

@implementation SUIWebViewCell

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.contentView.layoutMargins = UIEdgeInsetsMake(0, 8, 0, 0);
        
        m_view = [[WKWebView alloc] initWithFrame:self.bounds];
        
        [self.contentView addSubview:m_view];
    }
    
    return self;
}


- (void)setUrl:(NSString *)url
{
    m_url = url;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [m_view loadRequest:request];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    m_view.backgroundColor = backgroundColor;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];

    m_view.frame = self.contentView.bounds;
}


- (void)prepareForReuse
{
    
}

- (void)updateDataSource:(NSDictionary *)item
{
    self.url = [item objectForKey:@"url"];
}


@end
