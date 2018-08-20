//
//  main.m
//  AsusFnKeysDaemon
//
//  Created by Le Bao Hiep on 8/20/18.
//  Copyright © 2018 Apple. All rights reserved.
//

#if DEBUG
#define DEBUG_LOG(fmt, args...) IOLog(fmt, ## args)
#else
#define DEBUG_LOG(fmt, args...)
#endif

#define AsusFnKeysEventCode 0x8102

#import <Cocoa/Cocoa.h>
#import <sys/ioctl.h>
#import <sys/socket.h>
#import <sys/kern_event.h>
#import "BezelServices.h"
#import "OSD.h"
#include <dlfcn.h>

static void *(*_BSDoGraphicWithMeterAndTimeout)(CGDirectDisplayID arg0, BSGraphic arg1, int arg2, float v, int timeout) = NULL;

u_int32_t vendorID = 0;

struct AsusFnKeysMessage
{
    int type;
    int x;
    int y;
};

bool _loadBezelServices()
{
    // Load BezelServices framework
    void *handle = dlopen("/System/Library/PrivateFrameworks/BezelServices.framework/Versions/A/BezelServices", RTLD_GLOBAL);
    if (!handle) {
        NSLog(@"Error opening framework");
        return NO;
    }
    else {
        _BSDoGraphicWithMeterAndTimeout = dlsym(handle, "BSDoGraphicWithMeterAndTimeout");
        return _BSDoGraphicWithMeterAndTimeout != NULL;
    }
}

bool _loadOSDFramework()
{
    return [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/OSD.framework"] load];
}

void showKBoardBLightStatus(int level, int max)
{
    CGDirectDisplayID currentDisplayId = [NSScreen.mainScreen.deviceDescription [@"NSScreenNumber"] unsignedIntValue];
    if (_BSDoGraphicWithMeterAndTimeout != NULL)
    {
        // El Capitan and probably older systems
        if (level)
            _BSDoGraphicWithMeterAndTimeout(currentDisplayId, BSGraphicKeyboardBacklightMeter, 0x0, (float)level/max, 1);
        else
            _BSDoGraphicWithMeterAndTimeout(currentDisplayId, BSGraphicKeyboardBacklightDisabledMeter, 0x0, 0, 1);
    }
    else {
        // Sierra+
        if (level)
            [[NSClassFromString(@"OSDManager") sharedManager] showImage:OSDGraphicKeyboardBacklightMeter
                                                            onDisplayID:currentDisplayId priority:OSDPriorityDefault
                                                          msecUntilFade:1000
                                                         filledChiclets:(float)level
                                                          totalChiclets:max
                                                                 locked:NO];
        else
            [[NSClassFromString(@"OSDManager") sharedManager] showImage:OSDGraphicKeyboardBacklightDisabledMeter
                                                            onDisplayID:currentDisplayId priority:OSDPriorityDefault
                                                          msecUntilFade:1000
                                                         filledChiclets:0
                                                          totalChiclets:max
                                                                 locked:NO];
    }
}

int main(int argc, const char * argv[]) {
    printf("daemon started...\n");
    
    if (!_loadBezelServices())
    {
        _loadOSDFramework();
    }
    
    //system socket
    int systemSocket = -1;
    
    //create system socket to receive kernel event data
    systemSocket = socket(PF_SYSTEM, SOCK_RAW, SYSPROTO_EVENT);
    
    //struct for vendor code
    // ->set via call to ioctl/SIOCGKEVVENDOR
    struct kev_vendor_code vendorCode = {0};
    
    //set vendor name string
    strncpy(vendorCode.vendor_string, "com.hieplpvip", KEV_VENDOR_CODE_MAX_STR_LEN);
    
    //get vendor name -> vendor code mapping
    // ->vendor id, saved in 'vendorCode' variable
    ioctl(systemSocket, SIOCGKEVVENDOR, &vendorCode);
    
    //struct for kernel request
    // ->set filtering options
    struct kev_request kevRequest = {0};
    
    //init filtering options
    // ->only interested in objective-see's events kevRequest.vendor_code = vendorCode.vendor_code;
    
    //...any class
    kevRequest.kev_class = KEV_ANY_CLASS;
    
    //...any subclass
    kevRequest.kev_subclass = KEV_ANY_SUBCLASS;
    
    //tell kernel what we want to filter on
    ioctl(systemSocket, SIOCSKEVFILT, &kevRequest);
    
    //bytes received from system socket
    ssize_t bytesReceived = -1;
    
    //message from kext
    // ->size is cumulation of header, struct, and max length of a proc path
    char kextMsg[KEV_MSG_HEADER_SIZE + sizeof(struct AsusFnKeysMessage)] = {0};
    
    struct AsusFnKeysMessage* message = NULL;
    
    while(YES)
    {
        //printf("listening...\n");
        
        bytesReceived = recv(systemSocket, kextMsg, sizeof(kextMsg), 0);
        
        if (bytesReceived != sizeof(kextMsg)) continue;
        
        //struct for broadcast data from the kext
        struct kern_event_msg *kernEventMsg = {0};
        
        //type cast
        // ->to access kev_event_msg header
        kernEventMsg = (struct kern_event_msg*)kextMsg;
        
        //only care about 'process began' events
        if(AsusFnKeysEventCode != kernEventMsg->event_code)
        {
            //skip
            continue;
        }
        
        //printf("new message\n");
        
        //typecast custom data
        // ->begins right after header
        message = (struct AsusFnKeysMessage*)&kernEventMsg->event_data[0];
        
        printf("type:%d x:%d y:%d\n", message->type, message->x, message->y);
        
        showKBoardBLightStatus(message->x, message->y);
    }
    
    return 0;
}
