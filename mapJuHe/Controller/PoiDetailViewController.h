//
//  PoiDetailViewController.h
//  SearchV3Demo
//
//  Created by songjian on 13-8-16.
//  Copyright (c) 2013年 songjian. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AMapSearchKit/AMapCommonObj.h>
#import <MAMapKit/MAMapKit.h>

@interface PoiDetailViewController : UIViewController

@property (nonatomic, strong) MAPointAnnotation *poi;

@end
