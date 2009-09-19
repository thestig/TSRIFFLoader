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
	NSLog(@"RIFF: did register");
}

- (BOOL) writeDocument: (id<ACDocument>) document toURL: (NSURL*) absoluteURL ofType: (NSString*) type 
			forSaveOperation: (NSSaveOperationType) saveOperation error: (NSError**) outError
{
	return NO;
}

- (BOOL) loadCompoisteForDocument: (id<ACDocument>) document fromURL: (NSURL*) absoluteURL
{
	// Launch helper application
	
	// Parse retrieved XML
	
	// Populate our document with data
	
	// Clean up temp files

	return NO;
}

- (BOOL) readImageForDocument: (id<ACDocument>) document fromURL: (NSURL*) absoluteURL ofType: (NSString*) type
												error: (NSError**) outError
{
	NSLog(@"RIFF: readImageForDocument \"%@\"", absoluteURL);
	return [self loadCompoisteForDocument: document fromURL: absoluteURL];
}

- (NSNumber*) worksOnShapeLayers: (id) userObject
{
	return [NSNumber numberWithBool: NO];
}

@end
