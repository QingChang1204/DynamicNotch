//
//  DynamicNotch-Bridging-Header.h
//  DynamicNotch
//
//  Created by Winston Khoe on 15/08/24.
//

#ifndef DynamicNotch_Bridging_Header_h
#define DynamicNotch_Bridging_Header_h

#import "MediaRemote.h"
#import <CoreFoundation/CoreFoundation.h>

extern CFStringRef kMRMediaRemoteNowPlayingInfoDidChangeNotification;
extern void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t queue, void (^completion)(CFDictionaryRef));

#endif /* DynamicNotch_Bridging_Header_h */
