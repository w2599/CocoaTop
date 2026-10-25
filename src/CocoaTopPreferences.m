#import "CocoaTopPreferences.h"
#import "roothide.h"

// 根据当前应用的 Bundle ID 生成配置文件路径。
static NSString *CocoaTopPreferencesPath(void)
{
	NSString *filename = [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingPathExtension:@"plist"];
	return jbroot([@"/var/mobile/Library/Preferences" stringByAppendingPathComponent:filename]);
}

static NSDictionary *CocoaTopDefaultPreferences(void)
{
	return @{
		@"Columns" : @[@0, @1, @3, @5, @20, @6, @7, @9, @12, @13],
		@"UpdateInterval" : @"1",
		@"FullWidthCommandLine" : @NO,
		@"ColorDiffs" : @YES,
		@"AutoJumpNewProcess" : @NO,
		@"FirstColumnStyle" : @"Bundle Identifier",
		@"ShowHeader" : @YES,
		@"ShowFooter" : @YES,
		@"ShortenPaths" : @YES,
		@"SortColumn" : @1, @"SortDescending" : @NO,
		@"FilterColumn" : @0,
		@"ProcInfoMode" : @0,
		@"Mode0SortColumn" : @1001, @"Mode0SortDescending" : @NO,
		@"Mode1SortColumn" : @2000, @"Mode1SortDescending" : @NO,
		@"Mode2SortColumn" : @3002, @"Mode2SortDescending" : @YES,
		@"Mode3SortColumn" : @4001, @"Mode3SortDescending" : @NO,
	};
}

@interface CocoaTopPreferences ()
@property (strong) NSMutableDictionary *values;
@end

@implementation CocoaTopPreferences

+ (instancetype)sharedPreferences
{
	static CocoaTopPreferences *preferences;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		preferences = [CocoaTopPreferences new];
	});
	return preferences;
}

- (instancetype)init
{
	self = [super init];
	if (self)
		_values = [[NSDictionary dictionaryWithContentsOfFile:CocoaTopPreferencesPath()] mutableCopy] ?: [NSMutableDictionary dictionary];
	return self;
}

- (id)objectForKey:(NSString *)key
{
	return self.values[key];
}

- (void)setObject:(id)value forKey:(NSString *)key
{
	if (value)
		self.values[key] = value;
	else
	[self.values removeObjectForKey:key];
	[self.values writeToFile:CocoaTopPreferencesPath() atomically:YES];
}

- (void)removeObjectForKey:(NSString *)key
{
	[self setObject:nil forKey:key];
}

- (void)registerDefaults:(NSDictionary *)defaults
{
	[defaults enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
		if (!self.values[key])
			self.values[key] = value;
	}];
	[self.values writeToFile:CocoaTopPreferencesPath() atomically:YES];
}

- (void)reset
{
	self.values = [CocoaTopDefaultPreferences() mutableCopy];
	[self.values writeToFile:CocoaTopPreferencesPath() atomically:YES];
}

@end
