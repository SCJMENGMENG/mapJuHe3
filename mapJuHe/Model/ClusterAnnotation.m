//
//  ClusterAnnotation.m
//  mapJuHe
//
//  Created by scj on 2018/9/12.
//  Copyright © 2018年 scj. All rights reserved.
//

#import "ClusterAnnotation.h"

@implementation ClusterAnnotation

#pragma mark - compare

- (NSUInteger)hash
{
    NSString *toHash = [NSString stringWithFormat:@"%.5F%.5F%ld", self.coordinate.latitude, self.coordinate.longitude, (long)self.count];
    return [toHash hash];
}

- (BOOL)isEqual:(id)object
{
    return [self hash] == [object hash];
}

#pragma mark - Life Cycle

- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate count:(NSInteger)count
{
    self = [super init];
    if (self)
    {
        _coordinate = coordinate;
        _count = count;
        _pois  = [NSMutableArray arrayWithCapacity:count];
    }
    return self;
}

@end
