#import "PPUniversalCellFlags.h"

BOOL BBUniversalCellUseSwiftUI = YES;

__attribute__((constructor))
static void initialize_BBUniversalCellUseSwiftUI(void) {
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:@"BBUniversalCellUseSwiftUI"];
    if (val != nil) {
        BBUniversalCellUseSwiftUI = [val boolValue];
    }
}
