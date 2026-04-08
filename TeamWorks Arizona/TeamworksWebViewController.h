//
//  TeamworksWebViewController.h
//  TeamWorks Arizona
//
//  Created by Jason Cantor on 1/21/26.
//

#import <UIKit/UIKit.h>

@interface TeamworksWebViewController : UIViewController

@property (nonatomic, strong) NSString *urlString;

- (instancetype)initWithURL:(NSString *)urlString;

@end
