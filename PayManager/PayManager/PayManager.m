//
//  PayManager.m
//  PayManager
//
//  Created by Doman on 17/3/28.
//  Copyright © 2017年 doman. All rights reserved.
//

#import "PayManager.h"

@interface PayManager ()<WXApiDelegate>

//回调
@property (nonatomic,copy)CDMPayCompleteCallBack callBack;
//appScheme
@property (nonatomic,strong)NSMutableDictionary *appSchemeDict;


@end

@implementation PayManager

static  PayManager *payManager = nil;

+ (PayManager *)shareManager{
    
    static dispatch_once_t oneToken;
    dispatch_once(&oneToken, ^{
        
        payManager = [[PayManager alloc] init];
        
    });
    
    return payManager;
    
}

- (BOOL)cdm_handleUrl:(NSURL *)url{
    
    if ([url.host isEqualToString:@"pay"]) {// 微信
        return [WXApi handleOpenURL:url delegate:self];
    }
    else if ([url.host isEqualToString:@"safepay"]) {// 支付宝
        // 支付跳转支付宝钱包进行支付，处理支付结果(在app被杀模式下，通过这个方法获取支付结果）
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            NSString *resultStatus = resultDic[@"resultStatus"];
            NSString *errStr = resultDic[@"memo"];
            CDMPayStateCode errorCode = CDMStateCodeSuccess;
            switch (resultStatus.integerValue) {
                case 9000:// 成功
                    errorCode = CDMStateCodeSuccess;
                    break;
                case 6001:// 取消
                    errorCode = CDMStateCodeCancel;
                    break;
                default:
                    errorCode = CDMStateCodeFailure;
                    break;
            }
            if ([PayManager shareManager].callBack) {
                [PayManager shareManager].callBack(errorCode,errStr);
            }
        }];
        
        // 授权跳转支付宝钱包进行支付，处理支付结果
        [[AlipaySDK defaultService] processAuth_V2Result:url standbyCallback:^(NSDictionary *resultDic) {
            NSLog(@"result = %@",resultDic);
            // 解析 auth code
            NSString *result = resultDic[@"result"];
            NSString *authCode = nil;
            if (result.length>0) {
                NSArray *resultArr = [result componentsSeparatedByString:@"&"];
                for (NSString *subResult in resultArr) {
                    if (subResult.length > 10 && [subResult hasPrefix:@"auth_code="]) {
                        authCode = [subResult substringFromIndex:10];
                        break;
                    }
                }
            }
            NSLog(@"授权结果 authCode = %@", authCode?:@"");
        }];
        return YES;
    }
    else{
        return NO;
    }
}

- (void)cdm_registerApp{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *urlTypes = dict[@"CFBundleURLTypes"];
    for (NSDictionary *urlTypeDict in urlTypes) {
        NSString *urlName = urlTypeDict[@"CFBundleURLName"];
        NSArray *urlSchemes = urlTypeDict[@"CFBundleURLSchemes"];
        // 一般对应只有一个
        NSString *urlScheme = urlSchemes.lastObject;
        if ([urlName isEqualToString:CDMWECHATURLNAME]) {
            [self.appSchemeDict setValue:urlScheme forKey:CDMWECHATURLNAME];
            // 注册微信
            [WXApi registerApp:urlScheme];
        }
        else if ([urlName isEqualToString:CDMALIPAYURLNAME]){
            // 保存支付宝scheme，以便发起支付使用
            [self.appSchemeDict setValue:urlScheme forKey:CDMALIPAYURLNAME];
        }
        else{
            
        }
    }
}

- (void)cdm_payOrderMessage:(id)orderMessage callBack:(CDMPayCompleteCallBack)callBack{
    // 缓存block
    self.callBack = callBack;
    // 发起支付
    if ([orderMessage isKindOfClass:[PayReq class]]) {
        // 微信
        [WXApi sendReq:(PayReq *)orderMessage];
    }
    else if ([orderMessage isKindOfClass:[NSString class]]){
        // 支付宝
        [[AlipaySDK defaultService] payOrder:(NSString *)orderMessage fromScheme:self.appSchemeDict[CDMALIPAYURLNAME] callback:^(NSDictionary *resultDic){
            NSString *resultStatus = resultDic[@"resultStatus"];
            NSString *errStr = resultDic[@"memo"];
            CDMPayStateCode errorCode = CDMStateCodeSuccess;
            switch (resultStatus.integerValue) {
                case 9000:// 成功
                    errorCode = CDMStateCodeSuccess;
                    break;
                case 6001:// 取消
                    errorCode = CDMStateCodeCancel;
                    break;
                default:
                    errorCode = CDMStateCodeFailure;
                    break;
            }
            if ([PayManager shareManager].callBack) {
                [PayManager shareManager].callBack(errorCode,errStr);
            }
        }];
    }
}

#pragma mark - WXApiDelegate
- (void)onResp:(BaseResp *)resp {
    // 判断支付类型
    if([resp isKindOfClass:[PayResp class]]){
        //支付回调
        CDMPayStateCode errorCode = CDMStateCodeSuccess;
        NSString *errStr = resp.errStr;
        switch (resp.errCode) {
            case 0:
                errorCode = CDMStateCodeSuccess;
                errStr = @"订单支付成功";
                break;
            case -1:
                errorCode = CDMStateCodeFailure;
                errStr = resp.errStr;
                break;
            case -2:
                errorCode = CDMStateCodeCancel;
                errStr = @"用户中途取消";
                break;
            default:
                errorCode = CDMStateCodeFailure;
                errStr = resp.errStr;
                break;
        }
        if (self.callBack) {
            self.callBack(errorCode,errStr);
        }
    }
}

#pragma mark -- Setter & Getter

- (NSMutableDictionary *)appSchemeDict{
    if (_appSchemeDict == nil) {
        _appSchemeDict = [NSMutableDictionary dictionary];
    }
    return _appSchemeDict;
}



@end
