//
//  ViewController.m
//  AspectDemo
//
//  Created by zhz on 13/03/2018.
//  Copyright © 2018 zhz. All rights reserved.
//

#import "ViewController.h"
#import <os/lock.h>

static void performLocked(dispatch_block_t block) {
    // https://github.com/ibireme/YYKit/blob/4e1bd1cfcdb3331244b219cbd37cc9b1ccb62b7a/YYKit/Image/YYWebImageOperation.m 使用到
    
//    dispatch_semaphore_t signal = dispatch_semaphore_create(1);
//    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 2.0f * NSEC_PER_SEC);
//    dispatch_semaphore_wait(signal, timeout);
//    block();
//    dispatch_semaphore_signal(signal);

    // 10.0以上系统使用
    os_unfair_lock_t unfairLock = &(OS_UNFAIR_LOCK_INIT);
    os_unfair_lock_lock(unfairLock);
    block();
    os_unfair_lock_unlock(unfairLock);
}

@interface ViewController ()

@property(nonatomic, strong) NSString *name;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self log:YES];
    [[self class] rent];
    
    self.name = @"大精神交流法计算发";
    performLocked(^{
        NSLog(@"111122333");
    });
    
    [self read:@"原始"];
}

- (void)read:(NSString *)my {
    NSLog(@"read: %@", my);
    NSLog(@"name: %@", self.name);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self read:@"原始touchesBegan"];
}

- (void)log:(BOOL)animated {
    NSLog(@"orign selector");
}

+ (void)rent {
    NSLog(@"orign selector");
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"\n%@, %@", anInvocation.target, anInvocation.methodSignature);

    [super forwardInvocation:anInvocation];
    
    NSLog(@"\n%@, %@", anInvocation.target, anInvocation.methodSignature);
}

- (void)doesNotRecognizeSelector:(SEL)aSelector {
    NSLog(@"aaaaaaa");
}

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    return NO;
}

@end
