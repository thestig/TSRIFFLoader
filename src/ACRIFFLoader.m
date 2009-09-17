//
//  ACRIFFLoader.m
//  ACRIFFLoader
//
//  Created by The Stig on 16/09/09.
//  Copyright The Stig 2009 . All rights reserved.
//

#import "ACRIFFLoader.h"

@implementation ACRIFFLoader

+ (id) plugin
{
	return [[[self alloc] init] autorelease];
}

- (void) willRegister: (id<ACPluginManager>) pluginManager
{
	[pluginManager registerIOProviderForReading: self forUTI:@"com.corel.riff"];
}

- (void) didRegister
{
}

- (BOOL) writeDocument: (id<ACDocument>) document toURL: (NSURL*) absoluteURL ofType: (NSString*) type 
			forSaveOperation: (NSSaveOperationType) saveOperation error: (NSError**) outError
{
	return NO;
}

- (BOOL) loadCompoisteForDocument: (id<ACDocument>) document fromURL: (NSURL*) absoluteURL
{
	// Load the embedded preview, if there is one
	return NO;
}

- (BOOL) readImageForDocument: (id<ACDocument>) document fromURL: (NSURL*) absoluteURL ofType: (NSString*) type
												error: (NSError**) outError
{
	return NO;
}

- (NSNumber*) worksOnShapeLayers: (id) userObject
{
	return [NSNumber numberWithBool: NO];
}

@end
