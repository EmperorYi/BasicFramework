
#define  KEY_USERNAME_PASSWORD @"KEY_USERNAME_PASSWORD"
#define kNetWorkManager [NetWorkManager sharedInstance]

#import "NetWorkManager.h"
#import <MyUUID/SPIMyUUID.h>

#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetExportSession.h>
#import <AVFoundation/AVMediaFormat.h>

#define kTimeoutInterval  15


/**
 *  取
 */
#define kCookieID_KEY @"Cookie_key"

@interface NetWorkManager ()<UIAlertViewDelegate>

@property(nonatomic,strong)UIAlertView *myAlert;

@end


@implementation NetWorkManager
static NetWorkManager *network = nil;
+ (instancetype)sharedInstance;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        network = [[NetWorkManager alloc]initWithBaseURL:[NSURL URLWithString:_Environment_Domain]];
        
    });
    return network;
}
-(instancetype)initWithBaseURL:(NSURL *)url
{
    if (self = [super initWithBaseURL:url]) {
        
        /**
         *  先删除cookies
         */
        NSHTTPCookieStorage *cookieJar = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        
        NSArray *cookies = [NSArray arrayWithArray:[cookieJar cookies]];
        
        for (NSHTTPCookie *cookie in cookies) {
            [cookieJar deleteCookie:cookie];
        }
        
        self.responseSerializer = [AFJSONResponseSerializer serializer];
        
        self.responseSerializer.stringEncoding = NSUTF8StringEncoding;//默认 NSUTF8StringEncoding
        
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
        securityPolicy.allowInvalidCertificates = YES;
        self.securityPolicy = securityPolicy;
        
        [self.responseSerializer willChangeValueForKey:@"timeoutInterval"];
        [self.requestSerializer setTimeoutInterval:kTimeoutInterval];
        [self.requestSerializer didChangeValueForKey:@"timeoutInterval"];
        
        self.responseSerializer.acceptableContentTypes = [NSSet setWithArray:@[@"application/json", @"text/json", @"text/javascript",@"text/html", @"text/plain",@"application/atom+xml",@"application/xml",@"text/xml", @"image/*"]];
        
        self.securityPolicy=[AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [self.requestSerializer setValue:USER_ID forHTTPHeaderField:@"USER_ID"];
        [self.requestSerializer setValue:[NetWorkManager getUUID] forHTTPHeaderField:@"EquipmentOnlyLabeled"];
        [self.requestSerializer setValue:kVersion forHTTPHeaderField:@"version"];
        //    if (USER_TOKENID) {
        //
        //        [manager.requestSerializer setValue:USER_TOKENID forHTTPHeaderField:@"Cookie"];
        //    }
        //    NSArray *temp_array = [NAMEANDPWFORBASIC componentsSeparatedByString:@"#"];
        //    [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:temp_array[0] password:temp_array[1]];
        
        //    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        self.operationQueue.maxConcurrentOperationCount = 2;
    }
    return self;
}
/**
 *  手机唯一标示
 */
+(NSString *)getUUID
{
    NSString * strUUID = (NSString *)[SPIMyUUID load:KEY_USERNAME_PASSWORD];
    
    if ([NSString isNULL:strUUID])
    {
        CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
        
        strUUID = (NSString *)CFBridgingRelease(CFUUIDCreateString (kCFAllocatorDefault,uuidRef));
        
        [SPIMyUUID save:KEY_USERNAME_PASSWORD data:strUUID];
        
    }
    return strUUID;
}

/**
 *  同步请求
 *
 *  @param RequestType POST or GET
 *  @param URL        地址
 *  @param parameters 参数
 *  @param Controller 控制器
 *  @param success
 *
 */
+(void)SynchronizationForRequestType:(NSString *)RequestType WithURL:(NSString *)URL parameters:(NSString *)parametersStr Controller:(UIViewController *)Controller success:(void(^)(id response,id data))success
{
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",_Environment_Domain,URL]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    [request setHTTPMethod:RequestType];
    
    [request setValue:[USER_ID stringValue] forHTTPHeaderField:@"uid"];
    [request setValue:kVersion forHTTPHeaderField:@"version"];
    [request setValue:[NetWorkManager getUUID] forHTTPHeaderField:@"EquipmentOnlyLabeled"];
//    NSArray *temp_array = [NAMEANDPWFORBASIC componentsSeparatedByString:@"#"];
//    NSData *basicAuthCredentials = [[NSString stringWithFormat:@"%@:%@", temp_array[0], temp_array[1]] dataUsingEncoding:NSUTF8StringEncoding];
//    NSString *base64AuthCredentials = [basicAuthCredentials base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)0];
//    [request setValue:[NSString stringWithFormat:@"Basic %@", base64AuthCredentials] forHTTPHeaderField:@"Authorization"];
    
    if (parametersStr) {
        
        NSData *data = [parametersStr dataUsingEncoding:NSUTF8StringEncoding];
        
        [request setHTTPBody:data];
    }
    
    dispatch_semaphore_t disp = dispatch_semaphore_create(0);
    
    
    NSURLSessionDataTask *dataTask =  [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        
        
        success (response,data);
        
        
        
        dispatch_semaphore_signal(disp);
    }];
    
    
    [dataTask resume];
    dispatch_semaphore_wait(disp, DISPATCH_TIME_FOREVER);
}

/**
 *  Post请求
 *
 *  @param URL        地址
 *  @param parameters 参数
 *  @param Controller 控制器
 *  @param success
 *  @param failure
 */
+(void)requestDataForPOSTWithURL:(NSString *)URL parameters:(id)parameters Controller:(UIViewController *)Controller withUploadProgress:(uploadProgress)progress success:(requestSuccess)success failure:(requestFailure)failure
{
    if ([kNetworkType isEqualToString:kNoNetwork]) {
        failure(nil);
        return;
    }
    
    [kNetWorkManager POST:URL parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
        
        if (progress) {
            
            progress(uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
        }
        
    }success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        /**
         *  get Cookies
         */
//        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
//        if (![NSString isBlankString:[self getUserTokenIdInCookie:response.allHeaderFields[@"Set-Cookie"]]]) {
//            
//            if (!USER_TOKENID) {
//                
//                /**
//                 *   登录先存储用于比对相应的headerfile
//                 */
//                [FileCacheManager saveInMyLocalStoreForValue:[self getUserTokenIdInCookie:response.allHeaderFields[@"Set-Cookie"]] atKey:KEY_USER_TOKENID];
//                
//            }else
//            {
//                /**
//                 *  登录后比对相应的headerfile
//                 */
////                if (![[self getUserTokenIdInCookie:response.allHeaderFields[@"Set-Cookie"]] isEqualToString:USER_TOKENID]) {
////                    
////                }
//                [self alertShowWith:Controller];
//            }
//            NSLog(@"login  ---> %@",response.allHeaderFields);
//            NSLog(@"login  ---> cookie %@",response.allHeaderFields[@"Set-Cookie"]);
//            
//        }
        
        
        
        
        if (success) {
            success(responseObject);
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        failure(error);
        
    }];
    
}
/**
 *  get请求
 *
 *  @param URL        地址
 *  @param Controller 控制器
 *  @param success
 *  @param failure
 */
+(void)requestDataForGETWithURL:(NSString *)URL parameters:(id)parameters Controller:(UIViewController *)Controller withUploadProgress:(uploadProgress)progress success:(requestSuccess)success failure:(requestFailure)failure
{
    
    if ([kNetworkType isEqualToString:kNoNetwork]) {
        failure(nil);
        return;
    }
    
    [kNetWorkManager GET:URL parameters:parameters progress:^(NSProgress * _Nonnull downloadProgress) {
        
        if (progress) {
            
            progress(downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
        }
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        /**
         *  get Cookies
         */
//        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
//        if (![NSString isBlankString:[self getUserTokenIdInCookie:response.allHeaderFields[@"Set-Cookie"]]]) {
//            
//            /**
//             *  登录后比对相应的headerfile
//             */
////            if (![[self getUserTokenIdInCookie:response.allHeaderFields[@"Set-Cookie"]] isEqualToString:USER_TOKENID]) {
////                
////            }
//            [self alertShowWith:Controller];
//            NSLog(@"login  ---> %@",response.allHeaderFields);
//            NSLog(@"login  ---> cookie %@",response.allHeaderFields[@"Set-Cookie"]);
//        }
        
        
        if (success) {
            success(responseObject);
            
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        failure(error);
        
    }];
    
}
/**
 *  上传图片
 *
 *  @param parameters   上传图片预留参数---视具体情况而定 可移除
 *  @param images   上传的图片数组
 *  @parm width      图片要被压缩到的宽度
 *  @param urlString    上传的url
 *  @param success 上传成功的回调
 *  @param failure 上传失败的回调
 *  @param progress     上传进度
 */
+(void)UploadPicturesWithURL:(NSString *)URL parameters:(id)parameters images:(NSArray *)images withtargetWidth:(CGFloat )width withUploadProgress:(uploadProgress)progress success:(requestSuccess)success failure:(requestFailure)failure
{
    if ([kNetworkType isEqualToString:kNoNetwork]) {
        failure(nil);
        return;
    }
    [kNetWorkManager POST:URL parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        
        NSUInteger i = 0 ;
        
        /**出于性能考虑,将上传图片进行压缩*/
        for (UIImage * image in images) {
            
            //image设置指定宽度
            UIImage *  resizedImage =  [UIImage IMGCompressed:image targetWidth:width];
            
            NSData * imgData = UIImageJPEGRepresentation(resizedImage, .5);
            
            //拼接data
            [formData appendPartWithFileData:imgData name:[NSString stringWithFormat:@"picflie%ld",(long)i] fileName:[NSString stringWithFormat:@"%@.png",[NetWorkManager randomString]] mimeType:@"image/jpeg"];
            
            i++;
        }
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        
        if (progress) {
            
            progress(uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
        }
        
    } success:^(NSURLSessionDataTask * _Nonnull task, NSDictionary *  _Nullable responseObject) {
        
        success(responseObject);
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        failure(error);
        
    }];
}
/**
 *  视频上传
 *
 *  @param parameters   上传视频预留参数---视具体情况而定 可移除
 *  @param videoPath    上传视频的本地沙河路径
 *  @param urlString     上传的url
 *  @param successBlock 成功的回调
 *  @param failureBlock 失败的回调
 *  @param progress     上传的进度
 */
+(void)uploadVideoWithParameters:(NSDictionary *)parameters withVideoPath:(NSString *)videoPath withUrlString:(NSString *)urlString withUploadProgress:(uploadProgress)progress withSuccessBlock:(requestSuccess)successBlock withFailureBlock:(requestFailure)failureBlock
{
    if ([kNetworkType isEqualToString:kNoNetwork]) {
        failureBlock(nil);
        return;
    }
    
    /**获得视频资源*/
    
    AVURLAsset * avAsset = [AVURLAsset assetWithURL:[NSURL URLWithString:videoPath]];
    
    /**压缩*/
    
    //    NSString *const AVAssetExportPreset640x480;
    //    NSString *const AVAssetExportPreset960x540;
    //    NSString *const AVAssetExportPreset1280x720;
    //    NSString *const AVAssetExportPreset1920x1080;
    //    NSString *const AVAssetExportPreset3840x2160;
    
    AVAssetExportSession  *  avAssetExport = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPreset640x480];
    
    /**转化后直接写入Library---caches*/
    
    NSString *  videoWritePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:[NSString stringWithFormat:@"/output-%@.mp4",[NetWorkManager randomString]]];
    
    
    avAssetExport.outputURL = [NSURL URLWithString:videoWritePath];
    
    
    avAssetExport.outputFileType =  AVFileTypeMPEG4;
    
    
    [avAssetExport exportAsynchronouslyWithCompletionHandler:^{
        
        
        switch ([avAssetExport status]) {
                
                
            case AVAssetExportSessionStatusCompleted:
            {
                
                
                [kNetWorkManager POST:urlString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                    
                    //获得沙盒中的视频内容
                    
                    [formData appendPartWithFileURL:[NSURL fileURLWithPath:videoWritePath] name:@"write you want to writre" fileName:videoWritePath mimeType:@"video/mpeg4" error:nil];
                    
                } progress:^(NSProgress * _Nonnull uploadProgress) {
                    
                    if (progress) {
                        
                        progress(uploadProgress.completedUnitCount / uploadProgress.totalUnitCount);
                    }
                    
                } success:^(NSURLSessionDataTask * _Nonnull task, NSDictionary *  _Nullable responseObject) {
                    
                    successBlock(responseObject);
                    
                } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    
                    failureBlock(error);
                    
                }];
                
                break;
            }
            default:
                break;
        }
        
        
    }];

}
/**
 *  文件下载
 *
 *  @param parameters   文件下载预留参数---视具体情况而定 可移除
 *  @param savePath     下载文件保存路径
 *  @param urlString        请求的url
 *  @param successBlock 下载文件成功的回调
 *  @param failureBlock 下载文件失败的回调
 *  @param progress     下载文件的进度显示
 */
+(void)downLoadFileWithParameters:(NSDictionary *)parameters withSavaPath:(NSString *)savePath withUrlString:(NSString *)urlString withDownLoadProgress:(downloadProgress)progress withSuccessBlock:(requestSuccess)successBlock withFailureBlock:(requestFailure)failureBlock
{
    if ([kNetworkType isEqualToString:kNoNetwork]) {
        failureBlock(nil);
        return;
    }
    
    
    [kNetWorkManager downloadTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]] progress:^(NSProgress * _Nonnull downloadProgress) {
        
        if (progress) {
            
            progress(downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
        }
        
        
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        
        return  [NSURL URLWithString:savePath];
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        if (error) {
            
            failureBlock(error);
        }
        
    }];
}
/**
 *  取消所有的网络请求
 */
+(void)cancelAllRequest
{
    [kNetWorkManager.operationQueue cancelAllOperations];
}
/**
 *  取消指定的url请求
 *
 *  @param requestType 该请求的请求类型
 *  @param string      该请求的url
 */
+(void)cancelHttpRequestWithRequestType:(NSString *)requestType requestUrlString:(NSString *)string
{
    NSError * error;
    
    /**根据请求的类型 以及 请求的url创建一个NSMutableURLRequest---通过该url去匹配请求队列中是否有该url,如果有的话 那么就取消该请求*/
    
    NSString * urlToPeCanced = [[[kNetWorkManager.requestSerializer requestWithMethod:requestType URLString:string parameters:nil error:&error] URL] path];
    
    
    for (NSOperation * operation in kNetWorkManager.operationQueue.operations) {
        
        //如果是请求队列
        if ([operation isKindOfClass:[NSURLSessionTask class]]) {
            
            //请求的类型匹配
            BOOL hasMatchRequestType = [requestType isEqualToString:[[(NSURLSessionTask *)operation currentRequest] HTTPMethod]];
            
            //请求的url匹配
            
            BOOL hasMatchRequestUrlString = [urlToPeCanced isEqualToString:[[[(NSURLSessionTask *)operation currentRequest] URL] path]];
            
            //两项都匹配的话  取消该请求
            if (hasMatchRequestType&&hasMatchRequestUrlString) {
                
                [operation cancel];
                
            }
        }
        
    }
}
/**
 *  清除用户信息
 */
+(void)clearUserCaches
{
    [FileCacheManager DeleteValueInMyLocalStoreForKey:KEY_USER_ID];
}
/**
 *  创建日期字符串防止重复命名
 */
+(NSString *)randomString
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"yyyy_MM_dd_hh_mm_ss_"];
    return [formatter stringFromDate:[NSDate date]];
}





















#pragma mark - alertview
static UIViewController *tempVC = nil;
-(void)alertShowWith:(UIViewController *)VC
{
    tempVC = VC;
    [self.myAlert show];
}
-(UIAlertView *)myAlert
{
    if (!_myAlert) {
        
        _myAlert = [[UIAlertView alloc]initWithTitle:@"提示" message:@"您的帐号已在另一台设备登录，请重新登录" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    }
    return _myAlert;
}
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (tempVC) {
        
        tempVC = nil;
        
        [NetWorkManager clearUserCaches];
        [tempVC dismissViewControllerAnimated:YES completion:nil];
    }
}
/**
 *   解析Cookie获取kTokenID
 */
-(NSString *)getUserTokenIdInCookie:(NSString *)theCookie
{
    //例如 ：JSESSIONID=25F6DBC6AB286542F37D58B8EDBB84BD; Path=/pad, cookie_user=fsdf#~#sdfs.com; Expires=Tue, 26-Nov-2013 06:31:33 GMT, cookie_pwd=123465; Expires=Tue, 26-Nov-2013 06:31:33 GMT
    NSString *basic_str = @"";
//    
//    NSMutableArray *cookisArray=[NSMutableArray arrayWithCapacity:20];
//    NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
    
    NSArray *theArray = [theCookie componentsSeparatedByString:@"; "];
    
    for (int i =0 ; i<[theArray count]; i++) {
        
        NSString *val=theArray[i];
        if ([val rangeOfString:@"JSESSIONID="].length>0)
        {
            basic_str = val;
        }
    }
    
    
//    for (int i =0 ; i<[theArray count]; i++) {
//        NSString *val=theArray[i];
//        if ([val rangeOfString:@"="].length>0)
//        {
//            NSArray *subArray = [val componentsSeparatedByString:@"="];
//            for (int i =0 ; i<[subArray count]; i++) {
//                NSString *subVal=subArray[i];
//                if ([subVal rangeOfString:@","].length>0)
//                {
//                    NSArray *subArray2 = [subVal componentsSeparatedByString:@","];
//                    for (int i =0 ; i<[subArray2 count]; i++) {
//                        NSString *subVal2=subArray2[i];
//                        [cookisArray addObject:subVal2];
//                    }
//                }
//                else
//                {
//                    [cookisArray addObject:subVal];
//                }
//            }
//        }
//        else
//        {
//            [cookisArray addObject:val];
//        }
//    }
//    for (int idx=0; idx<cookisArray.count; idx+=2) {
//        NSString *key=cookisArray[idx];
//        NSString *value;
//        if ([key isEqualToString:@"JSESSIONID"])
//        {
//            value=[NSString stringWithFormat:@"%@,%@",cookisArray[idx+1],cookisArray[idx+2]];
//            idx+=1;
//        }
//        else
//        {
//            value=cookisArray[idx+1];
//        }
//        NSLog(@"cookie value:%@=%@",key,value);
//        [cookieProperties setObject:value forKey:key];
//    }
    
    
    return basic_str;
}


@end
