//
//  SEProjectFacade.m
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 ThinkMobiles. All rights reserved.
//

#import "ESNetworkFacade.h"

#import "ESNetworkManager.h"

#import "ESRequests.h"

#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>

static ESNetworkManager *sharedHTTPClient = nil;

static NSString *const kDefaultBaseURLString = @"http://random.cat/";

@implementation ESNetworkFacade

#pragma mark - Lifecycle

+ (ESNetworkManager *)HTTPClient
{
    @synchronized(self) {
        if (!sharedHTTPClient) {
            [self initHTTPClientWithRootPath:kDefaultBaseURLString withCompletion:nil];
        }
        return sharedHTTPClient;
    }
}

+ (void)initHTTPClientWithRootPath:(NSString*)baseURL withCompletion:(void(^)(void))completion
{
    @synchronized(self) {
        if (sharedHTTPClient) {
            
            [sharedHTTPClient cleanManagersWithCompletionBlock:^{
                
                sharedHTTPClient = nil;
                AFNetworkActivityIndicatorManager.sharedManager.enabled = NO;
                
                sharedHTTPClient = [[ESNetworkManager alloc] initWithBaseURL:[NSURL URLWithString:baseURL]];
                
                AFNetworkActivityIndicatorManager.sharedManager.enabled = YES;
                
                if (completion) {
                    completion();
                }
            }];
        } else {
            sharedHTTPClient = [[ESNetworkManager alloc] initWithBaseURL:[NSURL URLWithString:baseURL]];
            AFNetworkActivityIndicatorManager.sharedManager.enabled = YES;
            if (completion) {
                completion();
            }
        }
    }
}

#pragma mark - Actions

/**
 *  Cancel all operations
 */
+ (void)cancelAllOperations
{
    return [[self HTTPClient] cancelAllOperations];
}

/**
 *  Check whether the operation is in process
 *
 *  @return Returns 'YES' if any opretaion is in process
 */
+ (BOOL)isOperationInProcess
{
    return [[self HTTPClient] isOperationInProcess];
}

/**
 *  Check reachability
 */
+ (BOOL)isInternetReachable
{
    return [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus != AFNetworkReachabilityStatusNotReachable;
}

#pragma mark - Requests Builder

+ (ESNetworkOperation *)getRandomCatImageURLOnSuccess:(SuccessBlock)success
                                              onFailure:(FailureBlock)failure
{
    ESGetRandomCatRequest *request = [[ESGetRandomCatRequest alloc] init];
    
    ESNetworkOperation* operation = [[self  HTTPClient] createOperationWithNetworkRequest:request success:^(ESNetworkOperation *operation) {
        
        ESGetRandomCatRequest *request = (ESGetRandomCatRequest *)operation.networkRequest;
        
        if (success) {
            success(request.catImageURL);
        }
        
    } failure:^(ESNetworkOperation *operation, NSError *error, BOOL isCanceled) {
        if (failure) {
            failure(error, isCanceled);
        }
    }];
    
    return operation;
}

@end
