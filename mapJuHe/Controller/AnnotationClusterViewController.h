//
//  AnnotationClusterViewController.h
//  mapJuHe
//
//  Created by scj on 2018/9/11.
//  Copyright © 2018年 scj. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>

@interface AnnotationClusterViewController : UIViewController<MAMapViewDelegate>

@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) UIButton *refreshButton;

@end
