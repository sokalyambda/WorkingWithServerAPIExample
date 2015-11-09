//
//  SENetworkRequest.h
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 ThinkMobiles. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    ESRequestSerializationTypeJSON,
    ESRequestSerializationTypeHTTP
} ESRequestSerializationType;

@interface ESNetworkRequest : NSObject {
    @protected
    NSMutableDictionary *_parameters;
    NSString            *_method;
    NSMutableDictionary *_customHeaders;
    NSError             *_error;
    NSString            *_action;
    ESRequestSerializationType _serializationType;
}

@property (strong, nonatomic, readonly) NSString *action;
@property (strong, nonatomic, readonly) NSMutableDictionary *parameters;
@property (strong, nonatomic, readonly) NSString *method;
@property (strong, nonatomic, readonly) NSMutableDictionary *customHeaders;
@property (strong, nonatomic, readonly) NSMutableArray *files;
@property (strong, nonatomic) NSError *error;

@property (assign, nonatomic, readonly) ESRequestSerializationType serializationType;

- (BOOL)prepareAndCheckRequestParameters;
- (BOOL)prepareResponseObjectForParsing:(id)responseObject;
- (BOOL)parseJSONDataSucessfully:(id)responseObject error:(NSError* __autoreleasing *)error;
- (BOOL)setParametersWithParamsData:(NSDictionary*)data;

@end
