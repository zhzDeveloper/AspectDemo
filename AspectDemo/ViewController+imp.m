//
//  ViewController+imp.m
//  AspectDemo
//
//  Created by zhz on 13/03/2018.
//  Copyright © 2018 zhz. All rights reserved.
//

/*
 typedef struct objc_method *Method;
 typedef struct objc_ method {
     SEL method_name;
     char *method_types;
     IMP method_imp;
 };
 */
#import <objc/runtime.h>
#import <objc/message.h>
#import "ViewController+imp.h"

@implementation ViewController (imp)

+ (void)load {
    [self getAllMethodList];
    
    Class class = NSClassFromString(@"ViewController");
    
    SEL orignSel = NSSelectorFromString(@"log:");
    Method orignMethod = class_getInstanceMethod(class, orignSel);
    IMP orignImp = method_getImplementation(orignMethod);
    const char *typeDes = method_getTypeEncoding(orignMethod);
    
    SEL newSel = NSSelectorFromString(@"swl_log:");
    Method newMethod = class_getInstanceMethod(class, newSel);
    IMP newImp = method_getImplementation(newMethod);
    
    /**
     * 获取一个block的函数指针
     * block: 签名格式: method_return_type ^(id self, method_args...)
     * 返回block的指针,  创建出来的block 必须使用imp_removeBlock才能释放.
     * 注意: 第一个参数必须为self
     */
    id swl_block = ^(id self, BOOL animated) {
        printf("aaaaaaaaaa");
    };
    IMP blockImp = imp_implementationWithBlock(swl_block);
    //        class_replaceMethod(class, orignSel, blockImp, typeDes);

    
    /**
     * 使用指定的 SEL 和 IMP 为某个类增加一个新的方法
     * cls: 新增加方法的类
     * name: 新增方法的名字
     * imp: 要添加方法的指针, 就是新增方法的实现部分, 这个方法必须有至少两个参数:self and _cmd.
     * types: char 数组, 新增方法的参数
     * return YES: 方法添加成功, NO: 添加失败(比如新增方法的名字已经存在)
     *  (for example, the class already contains a method implementation with that name).
     *
     * 注意: class_addMethod 可以给子类增加(或者重写)父类的方法, 但是不能替换已存在的方法(如果想改变存在方法的指针, 使用method_setImplementation)
     */
    
    BOOL success = class_addMethod(class, newSel, newImp, typeDes);
    if (success) {
        /**
         * name: 原方法的名字.
         * imp: 新方法指针/实现
         */
        IMP o = class_replaceMethod(class, orignSel, newImp, typeDes);
        printf("bbbbbbbb");
    } else {
        method_exchangeImplementations(orignMethod, newMethod);
    }
    
    
    Class class1 = objc_lookUpClass("MyObject");
    if (!class1) {
        class1 = objc_allocateClassPair([UIViewController class], "MyObject", 0);
        Method method = class_getInstanceMethod(class1, newSel);
        BOOL hasAdd = class_addMethod(class1, newSel, method_getImplementation(method), method_getTypeEncoding(method));
        objc_registerClassPair(class1);
        Class class2 = objc_lookUpClass("MyObject");
        UIViewController *vc = [[class2 alloc] init];
        NSLog(@"class2: %@", vc);
        if (hasAdd) {
//            [vc performSelector:newSel];
        }
        
        // 注意`Class statedClass = self.class;`和`Class baseClass = object_getClass(self);`的区别，
        // 前者获取类对象，后者获取本类是由什么实例化。
        
    }
}

- (void)swl_log:(BOOL)animated {
    [self swl_log:animated];
    NSLog(@"new selector");
}

+ (void)getAllMethodList {
    /// Meta Class
    Class ca = objc_getMetaClass("ViewController");
    BOOL flag = class_isMetaClass(ca);
    NSLog(@"%zd", flag);
    
    uint count;
    /// 使用 Meta Class获取的是 类方法, 否则实例方法
    Method *methodList = class_copyMethodList(ca, &count);
    for (int i = 0; i < count; i++) {
        Method method = methodList[i];
        //5. 获取方法的实现
        IMP implement = method_getImplementation(method);
        printf("IMP IMP IMP IMP");
    }
    
}

@end
