//
//  BXPatchManager.m
//  AspectDemo
//
//  Created by zhz on 20/03/2018.
//  Copyright © 2018 zhz. All rights reserved.
//

#import "BXPatchManager.h"
#import "Aspects.h"
#import <UIKit/UIApplication.h>
#import <objc/runtime.h>
#import "BxTestProtocol.h"

@import JavaScriptCore;

@interface BXPatchManager()

@property (nonatomic, strong) JSContext *context;

@end
@implementation BXPatchManager

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BXPatchManager *manager = [self manager];
        [[NSNotificationCenter defaultCenter] addObserver:manager selector:@selector(startFix) name:UIApplicationDidFinishLaunchingNotification object:nil];
    });
}

+ (instancetype)manager {
    static BXPatchManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
        [manager startInjectToJavaScript];
    });
    return manager;
}

- (void)startFix {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"js"];
    NSString *jsCore = [[NSString alloc] initWithData:[[NSFileManager defaultManager] contentsAtPath:path] encoding:NSUTF8StringEncoding];
    if ([self.context respondsToSelector:@selector(evaluateScript:withSourceURL:)]) {
        [self.context evaluateScript:jsCore withSourceURL:[NSURL URLWithString:@"index.js"]];
    } else {
        [self.context evaluateScript:jsCore];
    }
}

- (void)startInjectToJavaScript {
    self.context = [[JSContext alloc] init];
    [self.context setExceptionHandler:^(JSContext *context, JSValue *value) {
        NSLog(@"oc catches the exception: %@", value);
    }];
    
    self.context[@"runPositionAfter"] = ^() {
        NSArray *args = [JSContext currentArguments];
        JSContext *context = [JSContext currentContext];
        if (args.count <= 1) {
            return;
        }
        NSString *classString = [args[0] toString];
        Class class = NSClassFromString(classString);
        [[BXPatchManager manager] addProtocolToClass:class];

        JSValue *instanceObject = args[1];
        NSDictionary *instanceMethods = [instanceObject toDictionary];
        for (NSString *jsMethodName in instanceMethods.allKeys) {
            JSValue *func = instanceObject[jsMethodName];
            SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@:",jsMethodName]);
            [class aspect_hookSelector:selector withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> info) {
                if ([context[classString] toObject] == nil) {
                    context[classString] = info.instance;
                }
                JSValue *value = [func callWithArguments:info.arguments];
                
                //TODO: 返回值hook处理
                NSLog(@"hook class %@", value);
            } error:nil];
            NSLog(@"aaaaa: %@", jsMethodName);
        }
    };
    
    self.context[@"runPositionBefore"] = ^() {
        NSArray *args = [JSContext currentArguments];
        if (args.count <= 1) {
            return;
        }
        Class class = NSClassFromString([args[0] toString]);
        SEL selector = NSSelectorFromString([args[1] toString]);
        [class aspect_hookSelector:selector withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info){
            
            NSLog(@"runPositionBefore");
        } error:nil];
    };
    
    self.context[@"runPositionBefore"] = ^() {
        NSArray *args = [JSContext currentArguments];
        if (args.count <= 1) {
            return;
        }
        Class class = NSClassFromString([args[0] toString]);
        SEL selector = NSSelectorFromString([args[1] toString]);
        [class aspect_hookSelector:selector withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info){
            
            NSLog(@"aaaaa");
        } error:nil];
    };
    
    self.context[@"log"] = ^() {
        NSArray *args = [JSContext currentArguments];
        NSLog(@"%@", args);
    };
    
}

- (void)addProtocolToClass:(Class)class {
    
//    BOOL ret = class_addProtocol(class, @protocol(BxTestProtocol));
//    if (ret) {
//        return;
//    }
    
    NSString *protocolName = [NSString stringWithFormat:@"Protocol%@", NSStringFromClass(class)];
    Protocol *protocol = objc_allocateProtocol([protocolName UTF8String]);
    if (protocol == nil) {
        return;
    }
    protocol_addProtocol(protocol, @protocol(JSExport));

    // 增加属性
    [self addPropertyToProtocol:protocol toClass:class];
    // 添加方法
    [self addMethodToProtocol:protocol toClass:class];
    
    objc_registerProtocol(protocol);
    
    BOOL flag = class_addProtocol(class, protocol);
    if (flag) {
        unsigned int oCount;
        objc_property_t _Nonnull *list = protocol_copyPropertyList(protocol, &oCount);
        for (int i = 0; i < oCount; i++) {
            objc_property_t property = list[i];
            const char *property_name = property_getName(property);
            NSLog(@"增加的属性: %@", [NSString stringWithUTF8String:property_name]);
        }
        NSLog(@"增加协议成功");
    }
}

- (void)addPropertyToProtocol:(Protocol *)protocol toClass:(Class)class {
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList(class, &outCount);
    for (int i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *property_name = property_getName(property);
        NSLog(@"property_name: %s", property_name);
        
        unsigned int attrCount;
        objc_property_attribute_t *attr = property_copyAttributeList(property, &attrCount);
        for (int j = 0; j < attrCount; j++) {
            NSLog(@"attribute.name = %s, attribute.value = %s", attr[j].name, attr[j].value);
        }
        protocol_addProperty(protocol, property_name, attr, attrCount, NO, YES);
    }
}

- (void)addMethodToProtocol:(Protocol *)protocol toClass:(Class)class  {
    /// Meta Class
    Class metaClass = objc_getMetaClass([NSStringFromClass(class) UTF8String]);
    
    uint count;
    /// 使用 Meta Class获取的是 类方法, 否则实例方法
    Method *classMethodList = class_copyMethodList(metaClass, &count);
    for (int i = 0; i < count; i++) {
        Method method = classMethodList[i];
        protocol_addMethodDescription(protocol, method_getName(method), method_getTypeEncoding(method), NO, NO);
    }
    
    uint count2;
    Method *instanceMethodList = class_copyMethodList(class, &count2);
    for (int i = 0; i < count2; i++) {
        Method method = instanceMethodList[i];
        protocol_addMethodDescription(protocol, method_getName(method), method_getTypeEncoding(method), NO, YES);
    }
    
}
@end
