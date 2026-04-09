//
//  PPLog.h
//  Pure Pets
//
//  Production-safe logging wrapper.
//  NSLog outputs to device console even in Release builds.
//  PPLog is stripped from Release builds via preprocessor.
//

#ifndef PPLog_h
#define PPLog_h

#ifdef DEBUG
    #define PPLog(fmt, ...) NSLog((@"[PP] " fmt), ##__VA_ARGS__)
#else
    #define PPLog(fmt, ...) do {} while(0)
#endif

#endif /* PPLog_h */
