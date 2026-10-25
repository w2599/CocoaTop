#import "THtmlViewController.h"
#import "BackButtonHandler.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation HtmlViewController

- (void)loadView
{
	self.view = [[UIWebView alloc] initWithFrame:UIScreen.mainScreen.bounds];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.navigationItem.title = self.pageTitle;
	self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
	self.indicator.color = [UIColor blackColor];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.indicator];

	UIWebView *webView = (UIWebView *)self.view;
	webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	webView.delegate = self;
	webView.opaque = YES;
	webView.backgroundColor = [UIColor whiteColor];
	if (!self.url) {
		[webView loadHTMLString:@"<html><body><p>Page resource not found.</p></body></html>" baseURL:nil];
		return;
	}

	NSError *error = nil;
	NSData *data = [NSData dataWithContentsOfURL:self.url options:0 error:&error];
	NSString *html = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
	if (html.length > 0) {
		[webView loadHTMLString:html baseURL:self.url.URLByDeletingLastPathComponent];
	} else {
		[webView loadHTMLString:@"<html><body><p>Unable to load this page.</p></body></html>" baseURL:nil];
	}
}

- (BOOL)navigationShouldPopOnBackButton
{
	UIWebView *webView = (UIWebView *)self.view;
	if (webView.canGoBack) {
		[webView goBack];
		return NO;
	}
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[self.indicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[self.indicator stopAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[self.indicator stopAnimating];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (id)initWithURL:(NSString *)url title:(NSString *)title;
{
	self = [super init];
	if (self != nil) {
		self.url = [[NSBundle mainBundle] URLForResource:url withExtension:@"html"];
		self.pageTitle = title;
	}
	return self;
}

@end

#pragma clang diagnostic pop
