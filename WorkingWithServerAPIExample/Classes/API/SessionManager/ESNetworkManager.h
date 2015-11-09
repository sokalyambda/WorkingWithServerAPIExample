//
//  SESessionManager.h
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 ThinkMobiles. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ESNetworkOperation.h"

typedef void (^CleanBlock)();

@interface ESNetworkManager : NSObject

@property (assign, atomic) NSInteger requestNumber;

@property (strong, nonatomic, readonly) NSURL *baseURL;

- (id)initWithBaseURL:(NSURL*)url;
- (void)cancelAllOperations;
- (void)cleanManagersWithCompletionBlock:(CleanBlock)block;

- (void)enqueueOperation:(ESNetworkOperation*)operation success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure;
- (ESNetworkOperation*)createOperationWithNetworkRequest:(ESNetworkRequest*)networkRequest success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure;

//check whether operation is in process
- (BOOL)isOperationInProcess;

@end
