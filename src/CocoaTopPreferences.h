#import <Foundation/Foundation.h>

@interface CocoaTopPreferences : NSObject
+ (instancetype)sharedPreferences;
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (void)registerDefaults:(NSDictionary *)defaults;
- (void)reset;
@end
