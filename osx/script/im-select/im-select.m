//  * Build
//
//    ```bash
//    clang -o im-select im-select.m -framework Foundation -framework Carbon
//    ````
//
//  * List current input source
//
//    ```bash
//    ./im-select
//    ```
//
//  * Set input source
//
//    ```bash
//    ./im-select com.apple.keylayout.ABC           # Set English keyboard
//    ./im-select com.apple.inputmethod.SCIM.ITABC  # Set Chinese keyboard
//    ```
//
//  See https://github.com/daipeihust/im-select/blob/9cd5278b185a9d6daa12ba35471ec2cc1a2e3012/macOS/im-select/im-select/main.m#L1
//  Created by DaiPei on 2018/5/29.
//  Copyright © 2018年 DaiPei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

int main(int argc, const char * argv[]) {
    int ret = 0;
    @autoreleasepool {
        TISInputSourceRef currentInputSource = TISCopyCurrentKeyboardInputSource();
        NSString *sourceId = (__bridge NSString *)(TISGetInputSourceProperty(currentInputSource, kTISPropertyInputSourceID));

        if (argc > 1) {
            NSString *inputSource = [NSString stringWithUTF8String:argv[1]];
            if (![inputSource isEqualToString:sourceId]) {
                NSDictionary *filter = [NSDictionary dictionaryWithObject:inputSource forKey:(NSString *)kTISPropertyInputSourceID];
                CFArrayRef keyboards = TISCreateInputSourceList((__bridge CFDictionaryRef)filter, false);
                if (keyboards) {
                    TISInputSourceRef selected = (TISInputSourceRef)CFArrayGetValueAtIndex(keyboards, 0);
                    ret = TISSelectInputSource(selected);
                    CFRelease(keyboards);
                } else {
                    ret = 1;
                }
            }
        } else {
          printf("%s\n", [sourceId UTF8String]);
        }

        CFRelease(currentInputSource);
    }
    return ret;
}
