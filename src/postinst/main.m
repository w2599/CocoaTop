//
//  main.m
//  CocoaTop
//
//  Created by SXX on 2021/1/4.
//  Copyright © 2021 SXX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "roothide.h"


int
main(int argc, char *argv[], char *envp[]) {
    if (geteuid() != 0) {
        printf("ERROR: This tool needs to be run as root.\n");
        return 1;
    }
    chown(jbroot("/Applications/CocoaTop.app/CocoaTop"), 0, 0);
    chmod(jbroot("/Applications/CocoaTop.app/CocoaTop"), 04755);
    return 0;
}
