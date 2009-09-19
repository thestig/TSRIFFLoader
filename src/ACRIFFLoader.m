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

- (BOOL) loadCompoisteForDocument: (id<ACDocument>) document fromURL: (NSURL*) absoluteURL
{
	BOOL result = NO;
	
	// Launch helper application
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath: [[NSBundle bundleWithIdentifier:@"stig.the.Acorn.ACRIFFLoader"] pathForAuxiliaryExecutable: @"riffopen"]];

	NSArray *arguments = [NSArray arrayWithObject: [absoluteURL path]];
	[task setArguments: arguments];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput: pipe];

	NSFileHandle *file = [pipe fileHandleForReading];

	[task launch];

	NSData *data = [file readDataToEndOfFile];

	NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	 
	// Parse retrieved XML
	NSXMLDocument *xml = [[NSXMLDocument alloc] initWithXMLString: output options: NSXMLDocumentTidyXML error: nil];
	NSXMLNode *root  = [xml rootElement];
	NSXMLNode *doc = [[root nodesForXPath: @"//document" error: nil] objectAtIndex: 0];

	// Populate our document with data
	if (doc)
	{
		// Load thumbnail
		CGImageRef imageRef;
		NSXMLElement *thumbnail = [[doc nodesForXPath: @"thumbnail" error: nil] objectAtIndex: 0];
		[self loadImage: &imageRef fromNode: thumbnail];
    
    if (imageRef) 
		{
			[document setCanvasSize: NSMakeSize(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef))];
			
			id <ACGroupLayer> baseGroup = [document baseGroup];
			[baseGroup insertCGImage: imageRef atIndex: 0 withName: NSLocalizedString(@"Background", @"Background")];
			
			CGImageRelease(imageRef);
			
			result = YES;
		}
		
		// Cleanup layers that may have been created
		NSArray *layers = [doc nodesForXPath:@"layer" error: nil];
		for (NSXMLElement* layer in layers)
		{
			//NSLog(@"layer: %@", layer);
			[self loadImage: nil fromNode: layer];
		}
	}
	
	[xml release];
	[task release];

	return result;
}

- (BOOL) readImageForDocument: (id<ACDocument>) document fromURL: (NSURL*) absoluteURL ofType: (NSString*) type
												error: (NSError**) outError
{
	//NSLog(@"RIFF: readImageForDocument \"%@\"", absoluteURL);
	return [self loadCompoisteForDocument: document fromURL: absoluteURL];
}

- (NSNumber*) worksOnShapeLayers: (id) userObject
{
	return [NSNumber numberWithBool: NO];
}

@end
