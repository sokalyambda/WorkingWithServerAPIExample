//
//  SENetworkRequest.h
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 Connexity. All rights reserved.
//

typedef enum : NSUInteger {
    BZRRequestSerializationTypeJSON,
    BZRRequestSerializationTypeHTTP
} BZRRequestSerializationType;

@interface ESNetworkRequest : NSObject {
    NSString            *_path;
    NSMutableDictionary *_parameters;
    NSString            *_method;
    NSMutableDictionary *_customHeaders;
    NSError             *_error;
    
    BOOL                _retryIfConnectionFailed;
    BOOL                _applicationAuthorizationRequired;
    BOOL                _userAuthorizationRequired;
}

@property (strong, nonatomic, readonly) NSString *path;
@property (strong, nonatomic, readonly) NSMutableDictionary *parameters;
@property (strong, nonatomic, readonly) NSString *method;
@property (strong, nonatomic, readonly) NSMutableDictionary *customHeaders;

//depends on API requirements
@property (assign, nonatomic, readonly) BOOL applicationAuthorizationRequired;
@property (assign, nonatomic, readonly) BOOL userAuthorizationRequired;

@property (assign, nonatomic, readonly) BOOL retryIfConnectionFailed;

@property (strong, nonatomic, readonly) NSMutableArray *files;
@property (strong, nonatomic) NSError *error;
@property (strong, nonatomic) NSString *action;

@property (assign, nonatomic) BZRRequestSerializationType serializationType;

- (BOOL)prepareAndCheckRequestParameters;
- (BOOL)parseResponseSucessfully:(id)responseObject;
- (BOOL)parseJSONDataSucessfully:(id)responseObject error:(NSError* __autoreleasing *)error;
- (BOOL)setParametersWithParamsData:(NSDictionary*)data;

@end
