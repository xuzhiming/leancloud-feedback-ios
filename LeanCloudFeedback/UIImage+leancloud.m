//
//  UIImage+leancloud.m
//  LeanCloudFeedback
//
//  Created by xzming on 2019/11/1.
//

#import "UIImage+leancloud.h"

@implementation UIImage (leancloud)

+ (instancetype)sdImageNamed:(NSString *)name {
    return [UIImage imageNamed:name inBundle:[NSBundle bundleForClass:NSClassFromString(@"LCUtils")] compatibleWithTraitCollection:nil];
}

@end
