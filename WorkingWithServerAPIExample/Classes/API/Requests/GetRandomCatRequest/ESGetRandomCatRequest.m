//
//  ESGetRandomCatRequest.m
//  WorkingWithServerAPIExample
//
//  Created by Eugenity on 09.11.15.
//  Copyright © 2015 ThinkMobiles. All rights reserved.
//

#import "ESGetRandomCatRequest.h"

static NSString *const kRequestAction = @"meow";

static NSString *const kCatImageURLString = @"file";

@implementation ESGetRandomCatRequest

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _action = kRequestAction;
        _method = @"GET";
        _serializationType = ESRequestSerializationTypeJSON;
        
        NSMutableDictionary *parameters = [@{ } mutableCopy];
        [self setParametersWithParamsData:parameters];
    }
    return self;
}

- (BOOL)parseJSONDataSucessfully:(id)responseObject error:(NSError *__autoreleasing *)error
{
    return !!(self.catImageURL = [NSURL URLWithString:responseObject[kCatImageURLString]]);
}

@end
