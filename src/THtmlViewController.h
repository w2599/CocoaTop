#import <UIKit/UIKit.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface HtmlViewController : UIViewController<UIWebViewDelegate>
@property(strong) NSURL *url;
@property(strong) NSString *pageTitle;
@property(strong) UIActivityIndicatorView *indicator;
- (id)initWithURL:(NSString *)url title:(NSString *)title;
@end
#pragma clang diagnostic pop
