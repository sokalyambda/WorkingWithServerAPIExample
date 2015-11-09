//
//  SENetworkRequest.m
//  WorkWithServerAPI
//
//  Created by EugeneS on 30.01.15.
//  Copyright (c) 2015 ThinkMobiles. All rights reserved.
//

#import "ESNetworkRequest.h"

@implementation ESNetworkRequest

#pragma mark - Lifecycle

- (id)init
{
    if (self = [super init]) {

        _action = @"";
        
        if (!_parameters) {
            _parameters = [NSMutableDictionary dictionary];
        }
        if(!_customHeaders) {
            _customHeaders = [NSMutableDictionary dictionary];
        }
        if(!_files) {
            _files = [NSMutableArray array];
        }
    }
    return self;
}

-(void)dealloc
{
    _error = nil;
}

#pragma mark - Methods

- (BOOL)setParametersWithParamsData:(NSDictionary*)data
{
    if (!_action) {
        return NO;
    }
    _parameters = [NSMutableDictionary dictionaryWithDictionary:data];
    
    return YES;
}

- (BOOL)prepareResponseObjectForParsing:(id)responseObject
{
    BOOL parseJSONData = NO;
    
    if (!responseObject) {
        _error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@ - response is empty", NSStringFromClass([self class])]
                                     code:-3000
                                 userInfo:@{NSLocalizedDescriptionKey: @"Response is empty."}];
        return parseJSONData;
    }
    
    NSError *error = nil;
    NSDictionary *json;
    
    if ([responseObject isKindOfClass:[NSData class]]) {
        json = [NSJSONSerialization
                JSONObjectWithData:responseObject
                options:kNilOptions
                error:&error];
    } else if ([responseObject isKindOfClass:[NSDictionary class]] || [responseObject isKindOfClass:[NSArray class]]) {
        json = responseObject;
    }
    
    NSLog(@"JSON:\n %@", json);
    
    if (error) {
        _error = error;
    } else {
        
        @try {
            NSError* error = nil;
            parseJSONData = [self parseJSONDataSucessfully:json error:&error];
            
            if (!_error) {
                _error = error;
            }
        }
        @catch (NSException *exception) {
            _error = [NSError errorWithDomain:@"com.thinkmobiles"
                                         code:-4000
                                     userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"name:%@\nreason:%@", exception.name, exception.reason]}];
        }
    }
    
    return parseJSONData;
}

/**
 *  Should be overrided in subclasses
 */
- (BOOL)parseJSONDataSucessfully:(id)responseObject error:(NSError* __autoreleasing  *)error
{
    return YES;
}

/**
 *  Check the parameters here, if needed
 */
- (BOOL)prepareAndCheckRequestParameters
{
    return YES;
}

@end