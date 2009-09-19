//
//  RIFFDocument.h
//  riffopen
//
//  Created by The Stig on 09-09-17.
//  Copyright 2009 The Stig. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RIFFDocument : NSObject 
{
	NSString* _filepath;
	short _width;
	short _height;
	short _layerCount;
	double _resolution;
	CGColorSpaceRef _deviceRGB;
}

- (id) initWithFile: (NSString*) filepath;
- (CGImageRef) getLayer: (int) layer 
							isVisible: (BOOL*) visible 
						layerOffset: (CGPoint*) offset 
					 layerOpacity: (double*) opacity 
							blendMode: (CGBlendMode*) mode
							layerName: (NSString**) lyrName;

@property (readonly, nonatomic) short width;
@property (readonly, nonatomic) short height;
@property (readonly, nonatomic) short layerCount;
@property (readonly, nonatomic) double resolution;

@end
