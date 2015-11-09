//
//  SESessionManager.h
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 Connexity. All rights reserved.
//

typedef enum : NSUInteger {
    BZRSessionTypeApplication,
    BZRSessionTypeUser
} BZRSessionType;

#import "BZRNetworkOperation.h"

typedef void (^CleanBlock)();

@interface ESNetworkManager : NSObject

@property (assign, atomic) NSInteger requestNumber;

@property (strong, nonatomic, readonly) NSURL *baseURL;

- (id)initWithBaseURL:(NSURL*)url;
- (void)cancelAllOperations;
- (void)cleanManagersWithCompletionBlock:(CleanBlock)block;

- (void)enqueueOperation:(BZRNetworkOperation*)operation success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure;
- (BZRNetworkOperation*)createOperationWithNetworkRequest:(BZRNetworkRequest*)networkRequest success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure;

//session validation
- (void)validateSessionWithType:(BZRSessionType)sessionType onSuccess:(SuccessBlock)success onFailure:(FailureBlock)failure;
- (BOOL)isSessionValidWithType:(BZRSessionType)sessionType;

//check whether operation is in process
- (BOOL)isOperationInProcess;

@end
