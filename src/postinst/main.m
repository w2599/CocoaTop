//
//  main.m
//  CocoaTop
//
//  Created by SXX on 2021/1/4.
//  Copyright © 2021 SXX. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/stat.h>
#import "roothide.h"


int
main(int argc, char *argv[], char *envp[]) {
    if (geteuid() != 0) {
        printf("ERROR: This tool needs to be run as root.\n");
        return 1;
    }
    chown(jbroot("/Applications/CocoaTop.app/CocoaTop"), 0, 0);
    chmod(jbroot("/Applications/CocoaTop.app/CocoaTop"), 04755);
    if (@available(iOS 10, *)) {
    } else {
        chmod(jbroot("/Applications/CocoaTop.app/CocoaTop_"), 0755);
        rename(jbroot("/Applications/CocoaTop.app/CocoaTop"), jbroot("/Applications/CocoaTop.app/CocoaTop1"));
        rename(jbroot("/Applications/CocoaTop.app/CocoaTop_"), jbroot("/Applications/CocoaTop.app/CocoaTop"));
        rename(jbroot("/Applications/CocoaTop.app/CocoaTop1"), jbroot("/Applications/CocoaTop.app/CocoaTop_"));
    }
    return 0;
}
