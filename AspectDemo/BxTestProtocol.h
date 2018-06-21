//
//  BxTestProtocol.h
//  AspectDemo
//
//  Created by zhz on 23/03/2018.
//  Copyright © 2018 zhz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JSExport.h>

@protocol BxTestProtocol <JSExport>

@property (nonatomic, strong) NSString *name;

- (void)read:(NSString *)p;

- (void)log:(BOOL)animated;
@end
