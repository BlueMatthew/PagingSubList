//
//  ViewController.m
//  PagingSubList
//
//  Created by Matthew Shi on 2020/6/6.
//  Copyright © 2020 Matthew Shi. All rights reserved.
//

#import "ViewController.h"
#import "MainView.h"

@interface ViewController ()
{
    SUIMainView *m_mainView;
}

@end

@implementation ViewController

- (void)loadView
{
    CGRect frame = [[UIScreen mainScreen] bounds];
    
    m_mainView = [[SUIMainView alloc] initWithFrame:frame];
    
    self.view = m_mainView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

@end
