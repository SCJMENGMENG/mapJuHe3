//
//  AnnotationClusterViewController.m
//  mapJuHe
//
//  Created by scj on 2018/9/11.
//  Copyright © 2018年 scj. All rights reserved.
//

#import "AnnotationClusterViewController.h"
#import "PoiDetailViewController.h"

#import "CoordinateQuadTree.h"
#import "ClusterAnnotation.h"

#import "ClusterAnnotationView.h"
#import "ClusterTableViewCell.h"
#import "CustomCalloutView.h"

#define kCalloutViewMargin  -12
#define Button_Height       70.0

@interface AnnotationClusterViewController ()<CustomCalloutViewTapDelegate>

@property (nonatomic, strong) CoordinateQuadTree* coordinateQuadTree;

@property (nonatomic, strong) CustomCalloutView *customCalloutView;

@property (nonatomic, strong) NSMutableArray *selectedPoiArray;

@property (nonatomic, assign) BOOL shouldRegionChangeReCalculate;

@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, strong) MAPointAnnotation *startAnnotation;
@property (nonatomic, strong) MAPointAnnotation *endAnnotation;

@end

@implementation AnnotationClusterViewController

#pragma mark - update Annotation

/* 更新annotation. */
- (void)updateMapViewAnnotationsWithAnnotations:(NSArray *)annotations
{
    /* 用户滑动时，保留仍然可用的标注，去除屏幕外标注，添加新增区域的标注 */
    NSMutableSet *before = [NSMutableSet setWithArray:self.mapView.annotations];
    [before removeObject:[self.mapView userLocation]];
    NSSet *after = [NSSet setWithArray:annotations];
    
    /* 保留仍然位于屏幕内的annotation. */
    NSMutableSet *toKeep = [NSMutableSet setWithSet:before];
    [toKeep intersectSet:after];
    
    /* 需要添加的annotation. */
    NSMutableSet *toAdd = [NSMutableSet setWithSet:after];
    [toAdd minusSet:toKeep];
    
    /* 删除位于屏幕外的annotation. */
    NSMutableSet *toRemove = [NSMutableSet setWithSet:before];
    [toRemove minusSet:after];
    
    /* 更新. */
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mapView addAnnotations:[toAdd allObjects]];
        
        [toRemove removeObject:self.startAnnotation];
        [toRemove removeObject:self.endAnnotation];
        [self.mapView removeAnnotations:[toRemove allObjects]];
    });
}

- (void)addAnnotationsToMapView:(MAMapView *)mapView
{
    @synchronized(self)
    {
        if (self.coordinateQuadTree.root == nil || !self.shouldRegionChangeReCalculate)
        {
            NSLog(@"tree is not ready.");
            return;
        }
        
        /* 根据当前zoomLevel和zoomScale 进行annotation聚合. */
        MAMapRect visibleRect = self.mapView.visibleMapRect;
        double zoomScale = self.mapView.bounds.size.width / visibleRect.size.width;
        double zoomLevel = self.mapView.zoomLevel;
        
        /* 也可根据zoomLevel计算指定屏幕距离(以50像素为例)对应的实际距离 进行annotation聚合. */
        /* 使用：NSArray *annotations = [weakSelf.coordinateQuadTree clusteredAnnotationsWithinMapRect:visibleRect withDistance:distance]; */
        //double distance = 50.f * [self.mapView metersPerPointForZoomLevel:self.mapView.zoomLevel];
        
        __weak typeof(self) weakSelf = self;
        dispatch_barrier_async(self.queue, ^{
            
            NSArray *annotations = [weakSelf.coordinateQuadTree clusteredAnnotationsWithinMapRect:visibleRect
                                                                                    withZoomScale:zoomScale
                                                                                     andZoomLevel:zoomLevel];
            
            NSLog(@"%ld---------",annotations.count);
            dispatch_async(dispatch_get_main_queue(), ^{
                /* 更新annotation. */
                [weakSelf updateMapViewAnnotationsWithAnnotations:annotations];
            });
        });
    }
}

#pragma mark - CustomCalloutViewTapDelegate

- (void)didDetailButtonTapped:(NSInteger)index
{
    PoiDetailViewController *detail = [[PoiDetailViewController alloc] init];
    detail.poi = self.selectedPoiArray[index];
    
    /* 进入POI详情页面. */
    [self.navigationController pushViewController:detail animated:YES];
}

#pragma mark - MAMapViewDelegate

- (void)mapView:(MAMapView *)mapView didDeselectAnnotationView:(MAAnnotationView *)view
{
    [self.selectedPoiArray removeAllObjects];
    [self.customCalloutView dismissCalloutView];
    self.customCalloutView.delegate = nil;
}

- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view
{
    ClusterAnnotation *annotation = (ClusterAnnotation *)view.annotation;
    for (MAPointAnnotation *poi in annotation.pois)
    {
        [self.selectedPoiArray addObject:poi];
    }
    
    [self.customCalloutView setPoiArray:self.selectedPoiArray];
    self.customCalloutView.delegate = self;
    
    // 调整位置
    self.customCalloutView.center = CGPointMake(CGRectGetMidX(view.bounds), -CGRectGetMidY(self.customCalloutView.bounds) - CGRectGetMidY(view.bounds) - kCalloutViewMargin);
    
    [view addSubview:self.customCalloutView];
}

- (void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    [self addAnnotationsToMapView:self.mapView];
}

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    
    if ([annotation isKindOfClass:[MAPointAnnotation class]])
    {
        static NSString *pointReuseIndetifier = @"pointReuseIndetifier";
        MAAnnotationView *annotationView = (MAAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
        if (annotationView == nil)
        {
            annotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndetifier];
            
            annotationView.canShowCallout = NO;
            
            NSLog(@"------------startAnnotation==nil-----------------");
        }
        NSLog(@"------------startAnnotation==true-----------------");
        annotationView.image = (annotation == self.startAnnotation) ? [UIImage imageNamed:@"default_navi_route_startpoint"] : [UIImage imageNamed:@"default_navi_route_endpoint"];
        annotationView.centerOffset = CGPointMake(0, -10);
        
        return annotationView;
    }
    
    if ([annotation isKindOfClass:[ClusterAnnotation class]])
    {
        /* dequeue重用annotationView. */
        static NSString *const AnnotatioViewReuseID = @"AnnotatioViewReuseID";
        
        ClusterAnnotationView *annotationView = (ClusterAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:AnnotatioViewReuseID];
        
        if (!annotationView)
        {
            annotationView = [[ClusterAnnotationView alloc] initWithAnnotation:annotation
                                                               reuseIdentifier:AnnotatioViewReuseID];
        }
        NSLog(@"----0-----");
        /* 设置annotationView的属性. */
        annotationView.annotation = annotation;
        annotationView.count = [(ClusterAnnotation *)annotation count];
        
        /* 不弹出原生annotation */
        annotationView.canShowCallout = NO;
        
        return annotationView;
    }
    
    return nil;
}

#pragma mark - SearchPOI

- (void)createQuadTree{
    
    
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    
    for (int i = 0; i< 10; i++) {
        MAPointAnnotation *annotaion = [[MAPointAnnotation alloc] init];
        annotaion.title = [NSString stringWithFormat:@"丸子%d",i];
        annotaion.subtitle = [NSString stringWithFormat:@"%d个🌹",i];
        annotaion.coordinate = CLLocationCoordinate2DMake(39.910267 + 0.01 *i, 116.370888  + 0.01 *i);
        
        [arr addObject:annotaion];
    }
    
    @synchronized(self)
    {
        self.shouldRegionChangeReCalculate = NO;
        
        // 清理
        [self.selectedPoiArray removeAllObjects];
        [self.customCalloutView dismissCalloutView];
        
        NSMutableArray *annosToRemove = [NSMutableArray arrayWithArray:self.mapView.annotations];
        [annosToRemove removeObject:self.mapView.userLocation];
        [annosToRemove removeObject:self.startAnnotation];
        [annosToRemove removeObject:self.endAnnotation];
        [self.mapView removeAnnotations:annosToRemove];
        
        __weak typeof(self) weakSelf = self;
        dispatch_async(self.queue, ^{
            /* 建立四叉树. */
            [weakSelf.coordinateQuadTree buildTreeWithPOIs:arr];
            weakSelf.shouldRegionChangeReCalculate = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf addAnnotationsToMapView:weakSelf.mapView];
            });
        });
    }
}

#pragma mark - Refresh Button Action

//- (void)refreshAction:(UIButton *)button
//{
//    [self searchPoiWithKeyword:@"街"];
//}

#pragma mark - Life Cycle

- (id)init
{
    if (self = [super init])
    {
        self.coordinateQuadTree = [[CoordinateQuadTree alloc] init];
        
        self.selectedPoiArray = [[NSMutableArray alloc] init];
        
        self.customCalloutView = [[CustomCalloutView alloc] init];
        
        self.queue = dispatch_queue_create("quadQueue", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setTitle:@"地图"];
    
    [self initMapView];
    
//    [self initSearch];
    
    [self initRefreshButton];
    
    _shouldRegionChangeReCalculate = NO;
    
//    [self searchPoiWithKeyword:@"KFC"];
    
    [self createQuadTree];
    
}

- (void)dealloc
{
    [self.coordinateQuadTree clean];
}

- (void)initMapView{
    if (self.mapView == nil) {
        self.mapView = [[MAMapView alloc] initWithFrame:self.view.bounds];
        self.mapView.allowsAnnotationViewSorting = NO;
        self.mapView.delegate = self;
    }
    
    self.mapView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - Button_Height);
    
    [self.view addSubview:self.mapView];
    
    self.mapView.visibleMapRect = MAMapRectMake(220880104, 101476980, 272496, 466656);
    
    self.startAnnotation.coordinate = CLLocationCoordinate2DMake(47.368758999, 123.964478);
    
    self.endAnnotation.coordinate = CLLocationCoordinate2DMake(41.18786000, 80.255033999);
    
    [self.mapView addAnnotation:self.startAnnotation];
    [self.mapView addAnnotation:self.endAnnotation];
    
    [self.mapView showAnnotations:@[self.startAnnotation] animated:NO];//控制放大缩小显示完全
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.mapView showAnnotations:@[self.startAnnotation,self.endAnnotation] animated:YES];
    });
}

- (void)initRefreshButton
{
    self.refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.refreshButton setFrame:CGRectMake(0, _mapView.frame.origin.y + _mapView.frame.size.height, _mapView.frame.size.width, Button_Height)];
    [self.refreshButton setTitle:@"重新加载数据" forState:UIControlStateNormal];
    [self.refreshButton setTitleColor:[UIColor purpleColor] forState:UIControlStateNormal];
    
//    [self.refreshButton addTarget:self action:@selector(refreshAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.refreshButton];
}

- (MAPointAnnotation *)startAnnotation
{
    if (_startAnnotation == nil) {
        _startAnnotation = [[MAPointAnnotation alloc] init];
        _startAnnotation.title = @"起点";
    }
    
    return _startAnnotation;
}

- (MAPointAnnotation *)endAnnotation
{
    if (_endAnnotation == nil) {
        _endAnnotation = [[MAPointAnnotation alloc] init];
        _endAnnotation.title = @"终点";
    }
    
    return _endAnnotation;
}


@end
