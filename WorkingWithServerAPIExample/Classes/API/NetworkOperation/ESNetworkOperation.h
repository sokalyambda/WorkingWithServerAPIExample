//
//  SENetworkOperation.h
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 ThinkMobiles. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ESNetworkOperation, ESNetworkRequest;

typedef void (^SuccessOperationBlock)(ESNetworkOperation* operation);
typedef void (^FailureOperationBlock)(ESNetworkOperation* operation, NSError* error, BOOL isCanceled);

typedef void (^SuccessBlock)(NSURL *catImageURL);
typedef void (^FailureBlock)(NSError* error, BOOL isCanceled);

typedef void (^ProgressBlock)(ESNetworkOperation* operation, long long totalBytesWritten, long long totalBytesExpectedToWrite);

@interface ESNetworkOperation : NSObject

@property (strong, nonatomic, readonly) ESNetworkRequest *networkRequest;

@property (copy, nonatomic) SuccessOperationBlock successBlock;
@property (copy, nonatomic) FailureOperationBlock failureBlock;

- (id)initWithNetworkRequest:(ESNetworkRequest*)networkRequest networkManager:(id)manager error:(NSError *__autoreleasing *)error;
- (void)setCompletionBlockAfterProcessingWithSuccess:(SuccessOperationBlock)success
                                             failure:(FailureOperationBlock)failure;
- (void)setProgressBlock:(ProgressBlock)block;

- (void)start;
- (void)pause;
- (void)cancel;
- (BOOL)isInProcess;

@end
