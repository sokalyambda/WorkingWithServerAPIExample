//
//  ESCatController.m
//  WorkingWithServerAPIExample
//
//  Created by Eugenity on 09.11.15.
//  Copyright © 2015 ThinkMobiles. All rights reserved.
//

#import "ESCatController.h"

#import "ESNetworkFacade.h"

#import <MBProgressHUD/MBProgressHUD.h>

@interface ESCatController ()

@property (weak, nonatomic) IBOutlet UIImageView *catImageView;

@end

@implementation ESCatController

#pragma mark - Actions

- (IBAction)loadNewCatClick:(id)sender
{
    __weak typeof(self)weakSelf = self;
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [ESNetworkFacade getRandomCatImageURLOnSuccess:^(NSURL *catImageURL) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSData *imageData = [[NSData alloc] initWithContentsOfURL:catImageURL];
            UIImage *catImage = [UIImage imageWithData:imageData];
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideAllHUDsForView:weakSelf.view animated:YES];
                weakSelf.catImageView.image = catImage;
            });
        });
        
    } onFailure:^(NSError *error, BOOL isCanceled) {
        [MBProgressHUD hideAllHUDsForView:weakSelf.view animated:YES];
    }];
}

@end
