//
//  ACRIFFLoader.m
//  ACRIFFLoader
//
//  Created by The Stig on 16/09/09.
//  Copyright 2009 The Stig. All rights reserved.
//

#import "ACRIFFLoader.h"

@implementation ACRIFFLoader

+ (id) plugin
{
	return [[[self alloc] init] autorelease];
}

- (void) willRegister: (id<ACPluginManager>) pluginManager
{
	[pluginManager registerIOProviderForReading: self forUTI: @"com.corel.riff"];
}

- (void) didRegister
{
	//NSLog(@"RIFF: did register");
}

- (BOOL) writeDocument: (id<ACDocument>) document toURL: (NSURL*) absoluteURL ofType: (NSString*) type 
			forSaveOperation: (NSSaveOperationType) saveOperation error: (NSError**) outError
{
	return NO;
}

- (NSXMLDocument*) parseRIFFDocumentAtURL: (NSURL*) absoluteURL
{
	// Launch helper application
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath: [[NSBundle bundleForClass: [self class]] pathForAuxiliaryExecutable: @"riffopen"]];
	
	NSArray *arguments = [NSArray arrayWithObject: [absoluteURL path]];
	[task setArguments: arguments];
	
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput: pipe];
	
	NSFileHandle *file = [pipe fileHandleForReading];
	
	[task launch];
	
	NSData *data = [file readDataToEndOfFile];
	
	NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	
	NSXMLDocument *xml = [[NSXMLDocument alloc] initWithXMLString: output options: NSXMLDocumentTidyXML error: nil];

  [output release];
	[task release];
	
	return [xml autorelease];
}

- (void) loadImage: (CGImageRef*) imageRef fromNode: (NSXMLNode*) node
{
	NSXMLElement *path = [[node nodesForXPath:@"path" error: nil] objectAtIndex: 0];
	NSURL *url = [NSURL fileURLWithPath: [path stringValue]];

	if (imageRef)
	{
		CGImageSourceRef imageSourceRef = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
		if (imageSourceRef) 
		{
			*imageRef = CGImageSourceCreateImageAtIndex(imageSourceRef, 0, NULL);
			CFRelease(imageSourceRef);
		}
	}
	// Delete file, it is no longer needed
	//NSLog(@" url to remove: %@", url);
	[[NSFileManager defaultManager] removeItemAtURL: url error: nil];
}

- (BOOL) readImageForDocument: (id<ACDocument>) document 
											fromURL: (NSURL*) absoluteURL 
											 ofType: (NSString*) type
												error: (NSError**) outError
{
	BOOL result = NO;

	NSXMLDocument *xml = [self parseRIFFDocumentAtURL: absoluteURL];
	// Parse retrieved XML
	NSXMLNode *root  = [xml rootElement];
	NSXMLNode *doc = [[root nodesForXPath: @"//document" error: nil] objectAtIndex: 0];

	// Populate document with data
	if (doc)
	{		
		// Figure out document size
		int docWidth = [[[[doc nodesForXPath:@"@width" error: nil] objectAtIndex: 0] objectValue] intValue];
		int docHeight = [[[[doc nodesForXPath:@"@height" error: nil] objectAtIndex: 0] objectValue] intValue];
		float dpi = [[[[doc nodesForXPath:@"@dpi" error: nil] objectAtIndex: 0] objectValue] floatValue];
		if (dpi < 1.0f)
			dpi = 72.0f;
		//NSLog(@"docwidth: %d docheight: %d dpi: %3.1f", docWidth, docHeight, dpi);
		if (docWidth < 1 || docHeight < 1)
		{
			// Well shit
			return NO;
		}
		
		NSSize canvasSize = NSMakeSize(docWidth, docHeight);
		[document setCanvasSize: canvasSize];
		[document setDpi: NSMakeSize(dpi, dpi)];

		// Load layers
		NSArray *layers = [doc nodesForXPath:@"layer" error: nil];
		int i = [layers count] - 1;
		while (i >= 0)
		{
			NSXMLElement* layer = [layers objectAtIndex: i];
			
			BOOL visible = [[[[layer nodesForXPath:@"@offset-x" error: nil] objectAtIndex: 0] objectValue] boolValue];
			int offsetx = [[[[layer nodesForXPath:@"@offset-x" error: nil] objectAtIndex: 0] objectValue] intValue];
			int offsety = [[[[layer nodesForXPath:@"@offset-y" error: nil] objectAtIndex: 0] objectValue] intValue];
			float opacity = [[[[layer nodesForXPath:@"@opacity" error: nil] objectAtIndex: 0] objectValue] floatValue];
			CGBlendMode mode = [[[[layer nodesForXPath:@"@blend-mode" error: nil] objectAtIndex: 0] objectValue] intValue];
			NSString *layerName = [[[layer nodesForXPath:@"@name" error: nil] objectAtIndex: 0] objectValue];
			
			CGImageRef imageRef;
			[self loadImage: &imageRef fromNode: layer];
			if (imageRef)
			{
				// Base layer should ignore these values
				if (i == 0)
				{
					layerName =  NSLocalizedString(@"Background", @"Background");
					opacity = 1.0f;
					mode = kCGBlendModeNormal;
					offsetx = 0;
					offsety = 0;
				}

				id <ACGroupLayer> baseGroup = [document baseGroup];
				id <ACBitmapLayer> layer    = [baseGroup insertCGImage: imageRef atIndex:0 withName: layerName];
				
				[layer setVisible: visible];
				[layer setOpacity: opacity];
				NSPoint drawDelta = NSMakePoint(offsetx, docHeight - (offsety + CGImageGetHeight(imageRef)));
				[layer setDrawDelta: drawDelta];
				[layer setCompositingMode: mode];
				
				CGImageRelease(imageRef);
				i--;

				result = YES;
			}
		}
	}
	
	return result;
}

- (NSNumber*) worksOnShapeLayers: (id) userObject
{
	return [NSNumber numberWithBool: NO];
}

@end
