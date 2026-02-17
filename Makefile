ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET := iphone:clang:latest:15.0
    ARCHS = arm64 arm64e
else ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
	TARGET := iphone:clang:latest:15.0
    ARCHS = arm64 arm64e
else
	TARGET := iphone:clang:latest:11.0
    ARCHS = arm64
endif
INSTALL_TARGET_PROCESSES = YouTube
FINALAPCKAGE = 1
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YouShare

$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
