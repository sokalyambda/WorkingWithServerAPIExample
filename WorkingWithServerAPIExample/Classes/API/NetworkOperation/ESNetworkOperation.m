//
//  SENetworkOperation.m
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 ThinkMobiles. All rights reserved.
//

#import "ESNetworkOperation.h"
#import "ESNetworkRequest.h"

#import "ESNetworkFacade.h"
#import "ESNetworkManager.h"
#import "ESNetworkRequest.h"

#import <AFNetworking.h>

static NSString *const kCountOfBytesSent = @"countOfBytesSent";
static NSString *const kCountOfBytesReceived = @"countOfBytesReceived";

NS_CLASS_AVAILABLE(10_9, 7_0)
@interface DataTask : NSURLSessionDataTask @end

NS_CLASS_AVAILABLE(10_9, 7_0)
@interface UploadTask : NSURLSessionUploadTask @end

NS_CLASS_AVAILABLE(10_9, 7_0)
@interface DownloadTask : NSURLSessionDownloadTask @end

@interface ESNetworkOperation ()

@property (strong, nonatomic, readwrite) ESNetworkRequest *networkRequest;
@property (strong, nonatomic) NSMutableURLRequest *urlRequest;

@property (strong, nonatomic) AFHTTPRequestOperation *operation;

@property (strong, nonatomic) DataTask      *dataTask;
@property (strong, nonatomic) DownloadTask  *downloadTask;
@property (strong, nonatomic) UploadTask    *uploadTask;

@property (weak, nonatomic) id networkManager;

@property (strong, nonatomic) NSDictionary *allHeaders;

@property (strong, nonatomic, readwrite) NSProgress *progress;
@property (strong, nonatomic) ProgressBlock progressBlock;

@property (assign, nonatomic) NSUInteger requestNumber;

@end

@implementation ESNetworkOperation

#pragma mark - Accessors

- (NSDictionary *)allHeaders
{
    return [self.operation.responseObject allHeaderFields];
}

#pragma mark - Lifecycle

- (id)initWithNetworkRequest:(ESNetworkRequest*)networkRequest
              networkManager:(id)manager
                       error:(NSError *__autoreleasing *)error
{
    BOOL passedParametersCheck = [networkRequest prepareAndCheckRequestParameters];
    
    if (!passedParametersCheck) {
        if (!networkRequest.error) {
            networkRequest.error = [NSError errorWithDomain:@"Internal inconsistency"
                                                       code:-2999
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Parameters didn't pass validation."}];
        }
        
        if(error) {
            *error = networkRequest.error;
        }
        
        return (self = [super init]);
    }
    
    _urlRequest = nil;
    AFHTTPRequestSerializer *serializer = nil;

    if ([NSURLSession class]) {
        NSAssert([manager isKindOfClass:[AFHTTPSessionManager class]], nil);
        
        AFHTTPSessionManager *networkManager = manager;
        serializer = networkManager.requestSerializer;
    } else {
        AFHTTPRequestOperationManager *networkManager = manager;
        serializer = networkManager.requestSerializer;
    }
    
    if ([networkRequest.files count] > 0) {
        self.urlRequest = [serializer  multipartFormRequestWithMethod:@"POST"
                                                            URLString:[[NSURL URLWithString:networkRequest.action
                                                                              relativeToURL:[ESNetworkFacade HTTPClient].baseURL] absoluteString]
                                                           parameters:networkRequest.parameters
                                            constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                                
                                                [networkRequest.files enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                                    //append formData
                                                }];
                                            }
                                                                error:error];
        
    } else {
        self.urlRequest = [serializer requestWithMethod:networkRequest.method
                                              URLString:[NSString stringWithFormat:@"%@%@", [ESNetworkFacade HTTPClient].baseURL, networkRequest.action]
                                             parameters:networkRequest.parameters
                                                  error:error];
    }

    if (*error) {
        return (self = [super init]);
    }
    
    //cookies handling
    [self.urlRequest setHTTPShouldHandleCookies:NO];
    
    //set custom headers
    __weak typeof(self)weakSelf = self;;
    [networkRequest.customHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [weakSelf.urlRequest addValue:obj forHTTPHeaderField:key];
    }];
    
    if ((self = [super init])) {
        
        _networkManager = manager;
        _networkRequest = networkRequest;
        
        void (^SuccessOperationBlock)(id operation, id responseObject) = ^(id operation, id responseObject) {
            
            BOOL success = [weakSelf.networkRequest prepareResponseObjectForParsing:responseObject];
            
            if (success) {
                if (weakSelf.successBlock) {
                    weakSelf.successBlock(weakSelf);
                }
            } else {
                if (weakSelf.failureBlock) {
                    weakSelf.failureBlock(weakSelf, weakSelf.networkRequest.error, NO);
                }
            }
        };
        
        void (^FailureOperationBlock)(id operation, NSError *error) = ^(id operation, NSError *error) {
            
            BOOL requestCanceled = NO;
            
            if (error.code == NSURLErrorCancelled) {
                weakSelf.networkRequest.error = error;
                requestCanceled = YES;
            } else {
                weakSelf.networkRequest.error = error;
            }
            
            if (weakSelf.failureBlock) {
                weakSelf.failureBlock(weakSelf, weakSelf.networkRequest.error, requestCanceled);
            }
        };
        
        if ([NSURLSession class]) {
            NSAssert([manager isKindOfClass:[AFHTTPSessionManager class]], nil);
            
            AFHTTPSessionManager *networkManager = manager;
            
            if ([self.networkRequest.files count] > 0) {
                NSProgress* progress;
                _uploadTask = (UploadTask*)[networkManager uploadTaskWithStreamedRequest:self.urlRequest
                                                                                progress:&progress
                                                                       completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
                    if (!error) {
                        SuccessOperationBlock(response, responseObject);
                    } else {
                        FailureOperationBlock(response, error);
                    }
                }];
                _progress = progress;
            } else {
                _dataTask = (DataTask *)[networkManager dataTaskWithRequest:self.urlRequest
                                                          completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
                    if (!error) {
                        SuccessOperationBlock(response, responseObject);
                    } else {
                        FailureOperationBlock(response, error);
                    }
                }];
            }
        } else {
            NSAssert([manager isKindOfClass:[AFHTTPRequestOperationManager class]], nil);
            AFHTTPRequestOperationManager *networkManager = manager;
            _operation = [networkManager HTTPRequestOperationWithRequest:self.urlRequest
                                                                 success:SuccessOperationBlock
                                                                 failure:FailureOperationBlock];
        }
    }
    return self;
}

- (void)dealloc
{
    if (_progressBlock) {
        if (_uploadTask) {
            [_uploadTask removeObserver:self forKeyPath:kCountOfBytesSent context:NULL];
        } else if(_downloadTask) {
            [_downloadTask removeObserver:self forKeyPath:kCountOfBytesReceived context:NULL];
        }
    }
}

- (void)setCompletionBlockAfterProcessingWithSuccess:(SuccessOperationBlock)success
                                             failure:(FailureOperationBlock)failure
{
    self.successBlock = success;
    self.failureBlock = failure;
}

#pragma mark - Public methods

- (void)setProgressBlock:(ProgressBlock)block
{
    if (block) {
        if (_uploadTask) {
            _progressBlock = block;
            [_uploadTask addObserver:self forKeyPath:kCountOfBytesSent options:NSKeyValueObservingOptionNew context:NULL];
        } else if (_downloadTask) {
            _progressBlock = block;
            [_downloadTask addObserver:self forKeyPath:kCountOfBytesReceived options:NSKeyValueObservingOptionNew context:NULL];
        } else {
            __weak typeof(self)weakSelf = self;
            if (self.networkRequest.files.count > 0) {
                [_operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
                    block(weakSelf, totalBytesWritten, totalBytesExpectedToWrite);
                }];
            }
        }
    }
}

/**
 *  Start the operation
 */
- (void)start
{
    if (_dataTask) {
        [_dataTask resume];
    } else if (_operation) {
        [_operation start];
    } else if (_uploadTask) {
        [_uploadTask resume];
    } else if (_downloadTask) {
        [_downloadTask resume];
    }
    if (!_downloadTask) {
        [ESNetworkFacade HTTPClient].requestNumber++;
        self.requestNumber = [ESNetworkFacade HTTPClient].requestNumber;
    }
}

/**
 *  Pause the operation
 */
- (void)pause
{
    if (_dataTask) {
        [_dataTask suspend];
    } else if (_operation) {
        [_operation pause];
    } else if (_uploadTask) {
        [_uploadTask suspend];
    } else if (_downloadTask) {
        [_downloadTask suspend];
    }
}

/**
 *  Cancel operation
 */
- (void)cancel
{
    if (_dataTask) {
        [_dataTask cancel];
    } else if (_operation) {
        [_operation cancel];
    } else if (_uploadTask) {
        [_uploadTask cancel];
    } else if (_downloadTask) {
        [_downloadTask cancel];
    }
}

/**
 *  Check whether any operation is in process
 *
 *  @return Returns 'YES'
 */
- (BOOL)isInProcess
{
    if (_dataTask) {
        return _dataTask.state == NSURLSessionTaskStateRunning;
    } else if (_uploadTask) {
        return _uploadTask.state == NSURLSessionTaskStateRunning;;
    } else if (_downloadTask) {
        return _downloadTask.state == NSURLSessionTaskStateRunning;;
    }
    return NO;
}

#pragma mark - Progress observer

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    id newValue = change[NSKeyValueChangeNewKey];
    
    if (![newValue isEqual:[NSNull null]] &&
        [newValue isKindOfClass:[NSNumber class]] &&
        self.progressBlock) {
        
        long long bytesSend = 0;
        long long totalBytesSend = 0;
        
        if (_uploadTask) {
            bytesSend = _uploadTask.countOfBytesSent;
        } else if (_downloadTask) {
            bytesSend = (NSInteger)_downloadTask.countOfBytesReceived;
            totalBytesSend = (NSInteger)_downloadTask.countOfBytesExpectedToReceive;
        }
        
        if (bytesSend > totalBytesSend) {
            bytesSend = totalBytesSend;
        }
        
        self.progressBlock(self, bytesSend, totalBytesSend);
    }
}

@end
