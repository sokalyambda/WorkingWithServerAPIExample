//
//  SEProjectFacade.h
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 eugenity. All rights reserved.
//

#import "BZRSessionManager.h"

@class BZRUserProfile, BZRLocationEvent;

@interface ESNetworkFacade : NSObject

+ (BZRSessionManager *)HTTPClient;

+ (NSString *)baseURLString;
+ (void)setBaseURLString:(NSString *)baseURLString;
+ (void)initHTTPClientWithRootPath:(NSString*)baseURL withCompletion:(void(^)(void))completion;

//internet checking
+ (BOOL)isInternetReachable;

//session validation
+ (BOOL)isUserSessionValid;
+ (BOOL)isFacebookSessionValid;

//cancel operations
+ (void)cancelAllOperations;

//check whether any operation is in process
+ (BOOL)isOperationInProcess;

@end