//
//  SEProjectFacade.m
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 Connexity. All rights reserved.
//

#import "ESNetworkFacade.h"

#import "BZRSessionManager.h"

#import "BZRRequests.h"

#import <AFNetworking/AFNetworkActivityIndicatorManager.h>

static BZRSessionManager *sharedHTTPClient = nil;

NSString *defaultBaseURLString = @"https://api.bizraterewards.com/v1/";
static NSString *_baseURLString;

@implementation ESNetworkFacade

#pragma mark - Accessors

+ (NSString *)baseURLString
{
    @synchronized(self) {
        BZREnvironment *savedEnvironment = [BZREnvironmentService environmentFromDefaultsForKey:CurrentAPIEnvironment];
        
        if (!savedEnvironment) {
            savedEnvironment = [BZREnvironmentService defaultEnvironment];
            [BZREnvironmentService setEnvironment:savedEnvironment toDefaultsForKey:CurrentAPIEnvironment];
        }
        
        if (!_baseURLString && savedEnvironment) {
            _baseURLString = savedEnvironment.apiEndpointURLString;
        }
        return _baseURLString;
    }
}

+ (void)setBaseURLString:(NSString *)baseURLString
{
    @synchronized(self) {
        _baseURLString = baseURLString;
    }
}

#pragma mark - Lifecycle

+ (BZRSessionManager *)HTTPClient
{
    if (!sharedHTTPClient) {
        [self initHTTPClientWithRootPath:[self baseURLString] withCompletion:nil];
    }
    return sharedHTTPClient;
}

+ (void)initHTTPClientWithRootPath:(NSString*)baseURL withCompletion:(void(^)(void))completion
{
    if (sharedHTTPClient) {
        
        [sharedHTTPClient cleanManagersWithCompletionBlock:^{
            
            sharedHTTPClient = nil;
            AFNetworkActivityIndicatorManager.sharedManager.enabled = NO;
            
            sharedHTTPClient = [[BZRSessionManager alloc] initWithBaseURL:[NSURL URLWithString:baseURL]];

            AFNetworkActivityIndicatorManager.sharedManager.enabled = YES;
            
            if (completion) {
                completion();
            }
        }];
    } else {
        sharedHTTPClient = [[BZRSessionManager alloc] initWithBaseURL:[NSURL URLWithString:baseURL]];
        AFNetworkActivityIndicatorManager.sharedManager.enabled = YES;
        if (completion) {
            completion();
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

+ (BOOL)isInternetReachable
{
    return [AFNetworkReachabilityManager sharedManager].networkReachabilityStatus != AFNetworkReachabilityStatusNotReachable;
}

@end
