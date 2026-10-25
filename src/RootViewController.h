#import <UIKit/UIKit.h>
#import "GridCell.h"
#import "PopupMenuView.h"

@interface RootViewController : UITableViewControllerWithMenu<UISearchBarDelegate>
- (BOOL)shouldShowFooter;
@end
