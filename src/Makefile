ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
APPLICATION_NAME = CocoaTop
ADDITIONAL_OBJCFLAGS = -fobjc-arc
CocoaTop_FILES = RootViewController.m SockViewController.m Proc.m ProcArray.m NetArray.m Sock.m Column.m GridCell.m Setup.m SetupColumns.m AppIcon.m TextViewController.m THtmlViewController.m PopupMenuView.m BackButtonHandler.m Compat.m AppDelegate.m CocoaTopPreferences.m PrivilegedClient.m main.m
CocoaTop_CFLAGS += -fno-ptrauth-objc-class-ro
CocoaTop_FRAMEWORKS = UIKit WebKit IOKit CoreGraphics MessageUI
CocoaTop_CODESIGN_FLAGS = -Stask.xml
CocoaTop_RESOURCE_DIRS = res

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk

TOOL_NAME = CocoaTopHelper
CocoaTopHelper_FILES = HelperMain.m PrivilegedClient.m
CocoaTopHelper_FRAMEWORKS = Foundation
CocoaTopHelper_CODESIGN_FLAGS = -Stask.xml
CocoaTopHelper_INSTALL_PATH = /Applications/CocoaTop.app
include $(THEOS_MAKE_PATH)/tool.mk

# SUBPROJECTS = postinst
include $(THEOS_MAKE_PATH)/aggregate.mk

#before-package::
#	@cp .theos/obj/five/CocoaTop.app/CocoaTop .theos/_/Applications/CocoaTop.app/CocoaTop5
#	@cp .theos/obj/six/CocoaTop.app/CocoaTop .theos/_/Applications/CocoaTop.app/CocoaTop6

after-install::
	install.exec 'uiopen -b cn.zqbb.ccatop.whitelist'
