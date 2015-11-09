//
//  SEProjectFacade.h
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 ThinkMobiles. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ESNetworkManager.h"

@interface ESNetworkFacade : NSObject

+ (ESNetworkManager *)HTTPClient;

+ (void)initHTTPClientWithRootPath:(NSString*)baseURL withCompletion:(void(^)(void))completion;

//internet checking
+ (BOOL)isInternetReachable;

//cancel operations
+ (void)cancelAllOperations;

//check whether any operation is in process
+ (BOOL)isOperationInProcess;

//Requests Builder
+ (ESNetworkOperation *)getRandomCatImageURLOnSuccess:(SuccessBlock)success
                                            onFailure:(FailureBlock)failure;

@end