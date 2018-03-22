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

@import JavaScriptCore;

@interface BXPatchManager()

@property (nonatomic, strong) JSContext *context;

@end
@implementation BXPatchManager

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BXPatchManager *manager = [self manager];
        [[NSNotificationCenter defaultCenter] addObserver:manager selector:@selector(startFix) name:UIApplicationWillEnterForegroundNotification object:nil];
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
    NSString *protocolName = [NSString stringWithFormat:@"Protocol%@", NSStringFromClass(class)];
    Protocol *protocol = objc_allocateProtocol([protocolName UTF8String]);
    if (protocol == nil) {
        return;
    }
    // 增加属性
    [self addPropertyToProtocol:protocol toClass:class];
    // 添加方法
    [self addMethodToProtocol:protocol toClass:class];
    
    Protocol *JSExport = objc_getProtocol("JSExport");
    protocol_addProtocol(protocol, JSExport);
    objc_registerProtocol(protocol);
    
    BOOL flag = class_addProtocol(class, protocol);
    if (flag) {
        NSLog(@"增加协议成功");
    }

    /*
    // 返回指定的协议
    Protocol * objc_getProtocol ( const char *name );
    // 获取运行时所知道的所有协议的数组
    Protocol ** objc_copyProtocolList ( unsigned int *outCount );
    // 创建新的协议实例
    Protocol * objc_allocateProtocol ( const char *name );
    // 在运行时中注册新创建的协议
    void objc_registerProtocol ( Protocol *proto );
    
    // 为协议添加方法
    void protocol_addMethodDescription ( Protocol *proto, SEL name, const char *types, BOOL isRequiredMethod, BOOL isInstanceMethod );
    
    // 添加一个已注册的协议到协议中
    void protocol_addProtocol ( Protocol *proto, Protocol *addition );
    // 为协议添加属性
    void protocol_addProperty ( Protocol *proto, const char *name, const objc_property_attribute_t *attributes, unsigned int attributeCount, BOOL isRequiredProperty, BOOL isInstanceProperty );
    // 返回协议名
    const char * protocol_getName ( Protocol *p );
    // 测试两个协议是否相等
    BOOL protocol_isEqual ( Protocol *proto, Protocol *other );
    // 获取协议中指定条件的方法的方法描述数组
    struct objc_method_description * protocol_copyMethodDescriptionList ( Protocol *p, BOOL isRequiredMethod, BOOL isInstanceMethod, unsigned int *outCount );
    // 获取协议中指定方法的方法描述
    struct objc_method_description protocol_getMethodDescription ( Protocol *p, SEL aSel, BOOL isRequiredMethod, BOOL isInstanceMethod );
    // 获取协议中的属性列表
    objc_property_t * protocol_copyPropertyList ( Protocol *proto, unsigned int *outCount );
    // 获取协议的指定属性
    objc_property_t protocol_getProperty ( Protocol *proto, const char *name, BOOL isRequiredProperty, BOOL isInstanceProperty );
    // 获取协议采用的协议
    Protocol ** protocol_copyProtocolList ( Protocol *proto, unsigned int *outCount );
    // 查看协议是否采用了另一个协议
    BOOL protocol_conformsToProtocol ( Protocol *proto, Protocol *other );
    */
}

- (void)addPropertyToProtocol:(Protocol *)protocol toClass:(Class)class {
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList(class, &outCount);
    for (int i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *property_name = property_getName(property);

        unsigned int attrCount;
        objc_property_attribute_t *attr = property_copyAttributeList(property, &attrCount);
        protocol_addProperty(protocol, property_name, attr, attrCount, NO, YES);
    }
}

- (void)addMethodToProtocol:(Protocol *)protocol toClass:(Class)class  {
    /// Meta Class
    Class metaClass = objc_getMetaClass("ViewController");
    
    uint count;
    /// 使用 Meta Class获取的是 类方法, 否则实例方法
    Method *classMethodList = class_copyMethodList(metaClass, &count);
    for (int i = 0; i < count; i++) {
        Method method = classMethodList[i];
        protocol_addMethodDescription(protocol, method_getName(method), method_getTypeEncoding(method), NO, NO);
    }
    
    uint count2;
    Method *instanceMethodList = class_copyMethodList(objc_getClass("ViewController"), &count2);
    for (int i = 0; i < count2; i++) {
        Method method = instanceMethodList[i];
        protocol_addMethodDescription(protocol, method_getName(method), method_getTypeEncoding(method), NO, YES);
    }
    
}
@end
