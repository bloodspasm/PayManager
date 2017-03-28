//
//  PayManager.h
//  PayManager
//
//  Created by Doman on 17/3/28.
//  Copyright © 2017年 doman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WXApi.h"
#import <AlipaySDK/AlipaySDK.h>

#define CDMWECHATURLNAME @"weixin"
#define CDMALIPAYURLNAME @"alipay"

typedef NS_ENUM(NSInteger){
    CDMStateCodeSuccess,// 成功
    CDMStateCodeFailure,// 失败
    CDMStateCodeCancel// 取消
}CDMPayStateCode;

typedef void(^CDMPayCompleteCallBack)(CDMPayStateCode stateCode ,NSString *stateMsg);

@interface PayManager : NSObject

//单例
+ (instancetype)shareManager;

//处理跳转url，回到应用，需要在delegate中实现
- (BOOL)cdm_handleUrl:(NSURL *)handleUrl;

//注册App，需要在 didFinishLaunchingWithOptions 中调用
- (void)cdm_registerApp;
/*
 * @param orderMessage 传入订单信息,如果是字符串，则对应是跳转支付宝支付；如果传入PayReq 对象，这跳转微信支付,注意，不能传入空字符串或者nil
 * @param callBack     回调，有返回状态信息
 */
- (void)cdm_payOrderMessage:(id)orderMessage callBack:(CDMPayCompleteCallBack)callBack;
@end
