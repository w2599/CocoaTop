THEOS_DEVICE_IP = 192.168.31.158
ARCHS = arm64e
TARGET = iphone:clang:13.7:6.0
APPLICATION_NAME = CocoaTop
ADDITIONAL_OBJCFLAGS = -fobjc-arc # -Wno-deprecated-declarations
CocoaTop_FILES = RootViewController.m SockViewController.m Proc.m ProcArray.m NetArray.m Sock.m Column.m GridCell.m Setup.m SetupColumns.m AppIcon.m TextViewController.m THtmlViewController.m PopupMenuView.m BackButtonHandler.m Compat.m AppDelegate.m main.m
CocoaTop_FRAMEWORKS = UIKit IOKit CoreGraphics MessageUI
CocoaTop_CODESIGN_FLAGS = -Stask.xml
#ifeq ($(TARGET),iphone:clang:7.0)
CocoaTop_RESOURCE_DIRS = res
#endif

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk

include $(THEOS_MAKE_PATH)/aggregate.mk

clean ::
	rm -rf .theos
	rm -rf packages
	
	
