//
//  riffloader
//
//  Created by The Stig on 09-09-17.
//  Copyright 2009 The Stig. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RIFFDocument.h"

// Adapted from Apple Sample code
void ExportCGDrawingAsPNG(CGImageRef image, double dpi, CFURLRef url)
{
	CFTypeRef keys[2], values[2]; 
	CFDictionaryRef properties = NULL;
	
	// Create a CGImageDestination object will write PNG data to URL.
	// We specify that this object will hold 1 image.
	CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
	
	// Set the keys to be the x and y resolution properties of the image.
	keys[0] = kCGImagePropertyDPIWidth;
	keys[1] = kCGImagePropertyDPIHeight;
	
	// Create a CFNumber for the resolution and use it as the 
	// x and y resolution.
	values[0] = values[1] = CFNumberCreate(NULL, kCFNumberFloatType, &dpi);
	
	// Create an properties dictionary with these keys.
	properties = CFDictionaryCreate(NULL, 
																	(const void **)keys, 
																	(const void **)values, 
																	2,  
																	&kCFTypeDictionaryKeyCallBacks,
																	&kCFTypeDictionaryValueCallBacks); 
	CFRelease(values[0]);
	
	// Add the image to the destination, characterizing the image with
	// the properties dictionary.
	CGImageDestinationAddImage(imageDestination, image, properties);
	CFRelease(properties);
	
	// Finalize will write data to disk.
	CGImageDestinationFinalize(imageDestination);
	
	// Release the CGImageDestination when finished with it.
	CFRelease(imageDestination);
}

NSURL* UniquePath()
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	NSString *str = (NSString*)CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);
	return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@.png", NSTemporaryDirectory(), [str autorelease]]];
}

int main (int argc, const char * argv[]) 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSXMLElement *root = [[NSXMLElement alloc] initWithName: @"riff"];

	for (int i = 1; i < argc; i++)
	{
		NSString *path = [NSString stringWithCString: argv[i] encoding: NSUTF8StringEncoding];
		//NSLog(@"Opening file: %@", path);
		RIFFDocument *riffdoc = [[RIFFDocument alloc] initWithFile: path];
		if (riffdoc)
		{
			NSXMLElement *doc = [[NSXMLElement alloc] initWithName: @"document"];
			[doc setAttributes: [NSArray arrayWithObjects:
														[NSXMLNode attributeWithName: @"width" stringValue:[NSString stringWithFormat: @"%d", riffdoc.width]],
														[NSXMLNode attributeWithName: @"height" stringValue:[NSString stringWithFormat: @"%d", riffdoc.height]],
														[NSXMLNode attributeWithName: @"dpi" stringValue:[NSString stringWithFormat: @"%3.1f", riffdoc.resolution]],
														nil]];

			for (int k = 0; k < riffdoc.layerCount; k++) 
			{
				BOOL visible;
				CGPoint offset;
				double opacity;
				CGBlendMode mode;
				NSString *lyrName;
				CGImageRef img = [riffdoc getLayer: k 
																 isVisible: &visible 
															 layerOffset: &offset 
															layerOpacity: &opacity 
																 blendMode: &mode
																 layerName: &lyrName];
				if (img)
				{
					NSXMLElement *layerDesc = [[NSXMLElement alloc] initWithName: @"layer"];
					[layerDesc setAttributes: [NSArray arrayWithObjects:
																		 [NSXMLNode attributeWithName: @"id" stringValue: [NSString stringWithFormat: @"%d", k]],
																		 [NSXMLNode attributeWithName: @"width" stringValue: [NSString stringWithFormat: @"%d", CGImageGetWidth(img)]],
																		 [NSXMLNode attributeWithName: @"height" stringValue: [NSString stringWithFormat: @"%d", CGImageGetHeight(img)]],
																		 [NSXMLNode attributeWithName: @"visible" stringValue: [NSString stringWithFormat: @"%d", visible]],
																		 [NSXMLNode attributeWithName: @"offset-x" stringValue: [NSString stringWithFormat: @"%3.1f", offset.x]],
																		 [NSXMLNode attributeWithName: @"offset-y" stringValue: [NSString stringWithFormat: @"%3.1f", offset.y]],
																		 [NSXMLNode attributeWithName: @"opacity" stringValue: [NSString stringWithFormat: @"%4.3f", opacity]],
																		 [NSXMLNode attributeWithName: @"blend-mode" stringValue: [NSString stringWithFormat: @"%d", mode]],
																		 [NSXMLNode attributeWithName: @"name" stringValue: lyrName],
																		 nil]];
					NSURL *url = UniquePath();
					NSXMLElement *layerPath = [[NSXMLElement alloc] initWithName: @"path" stringValue: [url path]];
					[layerDesc addChild: layerPath];
					ExportCGDrawingAsPNG(img, riffdoc.resolution, (CFURLRef)url);
					
					[doc addChild: layerDesc];
					CGImageRelease(img);
				}
			}
			
			[root addChild: doc];
			[riffdoc release];
		}

		NSXMLDocument *xml = [[NSXMLDocument alloc] initWithRootElement: root];
		printf("%s", (const char*)[[xml XMLData] bytes]);
		[xml release];

	}

	[pool drain];
	return 0;
}
