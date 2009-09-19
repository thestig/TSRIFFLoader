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
	[task setLaunchPath: [[NSBundle bundleWithIdentifier:@"stig.the.Acorn.ACRIFFLoader"] pathForAuxiliaryExecutable: @"riffopen"]];
	
	NSArray *arguments = [NSArray arrayWithObject: [absoluteURL path]];
	[task setArguments: arguments];
	
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput: pipe];
	
	NSFileHandle *file = [pipe fileHandleForReading];
	
	[task launch];
	
	NSData *data = [file readDataToEndOfFile];
	
	NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	
	NSXMLDocument *xml = [[NSXMLDocument alloc] initWithXMLString: output options: NSXMLDocumentTidyXML error: nil];
	
	[task release];
	
	return xml;
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
	
	NSXMLDocument *xml = [self parseRIFFDocumentAtURL: absoluteURL];
	// Parse retrieved XML
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

	return result;
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
		// Cleanup thumbnail, if any
		NSXMLElement *thumbnail = [[doc nodesForXPath: @"thumbnail" error: nil] objectAtIndex: 0];
		[self loadImage: NULL fromNode: thumbnail];
		
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
			i--;
			
			BOOL visible = [[[[layer nodesForXPath:@"@offset-x" error: nil] objectAtIndex: 0] objectValue] boolValue];
			int offsetx = [[[[layer nodesForXPath:@"@offset-x" error: nil] objectAtIndex: 0] objectValue] intValue];
			int offsety = [[[[layer nodesForXPath:@"@offset-y" error: nil] objectAtIndex: 0] objectValue] intValue];
			float opacity = [[[[layer nodesForXPath:@"@opacity" error: nil] objectAtIndex: 0] objectValue] floatValue];
			CGBlendMode mode = [[[[layer nodesForXPath:@"@blend-mode" error: nil] objectAtIndex: 0] objectValue] intValue];
			
			CGImageRef imageRef;
			[self loadImage: &imageRef fromNode: layer];
			if (imageRef)
			{
				//FIXME: add real name
				NSString *name = NSLocalizedString(@"Background", @"Background");//@"test";//NSString stringWithUTF8String:(const char *)psdLayer.layer_name];
				
				id <ACGroupLayer> baseGroup = [document baseGroup];
				id <ACBitmapLayer> layer    = [baseGroup insertCGImage: imageRef atIndex:0 withName: name];
				
				if (i > 0)
				{
					[layer setVisible: visible];
					[layer setOpacity: opacity];
					NSPoint drawDelta = NSMakePoint(offsetx, docHeight - offsety);
					[layer setDrawDelta: drawDelta];
				}
				
				CGImageRelease(imageRef);

				result = YES;
			}
		}
	}
	
	[xml release];

	return result;
#if 0
	NSSize canvasSize = NSMakeSize(pdfContext->width, pdfContext->height);
	[document setCanvasSize:canvasSize];
	[document setDpi:NSMakeSize(pdfContext->resolution_info.hres, pdfContext->resolution_info.hres)];
	
	int i = pdfContext->layer_count;
	while (i > 0) {
		psd_layer_record psdLayer = pdfContext->layer_records[i - 1];
		i--;
		
		if ((psdLayer.width == 0) || (!psdLayer.image_data) || (!*psdLayer.image_data)) {
			debug(@"no dater for layer %d", i);
			continue;
		}
		
		
		CGContextRef context;
		size_t destBytesPerRow = psdLayer.width * 4;
		//destBytesPerRow = COMPUTE_BEST_BYTES_PER_ROW(destBytesPerRow);
		psd_argb_color *outDest = calloc(1, destBytesPerRow * psdLayer.height);
		
		//#define PSD_VIMAGE
		
#ifdef PSD_VIMAGE
		
		vImage_Buffer src  = { psdLayer.image_data, psdLayer.width, psdLayer.height, destBytesPerRow };
		vImage_Buffer dest = { outDest, psdLayer.width, psdLayer.height, psdLayer.width * 4 };
		vImagePremultiplyData_ARGB8888(&src, &dest, kvImageNoFlags);
		
#else
		psd_argb_color * dst_color = outDest;
		psd_argb_color * src_color = psdLayer.image_data;
		int j = psdLayer.width * psdLayer.height;
		while (j > 0) {
			j--;
			psd_argb_color temp = *src_color;
			
			//debug(@"temp: %x", temp);
			//debug(@"j: %d", j);
			
			psd_uchar sA = ACPSDGetAlpha(temp);
			psd_uchar sR = ACPSDGetRed(temp);
			psd_uchar sG = ACPSDGetGreen(temp);
			psd_uchar sB = ACPSDGetBlue(temp);
			
			psd_uchar dR = (sR * sA + 127) / 255;
			psd_uchar dG = (sG * sA + 127) / 255;
			psd_uchar dB = (sB * sA + 127) / 255;
			psd_uchar dA = sA;
			
			*dst_color = CFSwapInt32BigToHost(ACPSDARGBToColor(dA, dR, dG, dB));
			
			src_color++;
			dst_color++;
		}
#endif
		
		context = CGBitmapContextCreate(outDest, psdLayer.width, psdLayer.height, 8, destBytesPerRow, 
																		CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB),
																		kCGImageAlphaPremultipliedFirst);
		
		if (context) {
			CGImageRef imageRef = CGBitmapContextCreateImage(context);
			
			NSString *name = [NSString stringWithUTF8String:(const char *)psdLayer.layer_name];
			
			id <ACGroupLayer> baseGroup = [document baseGroup];
			id <ACBitmapLayer> layer    = [baseGroup insertCGImage:imageRef atIndex:0 withName:name];
			
			[layer setVisible:psdLayer.visible];
			
			[layer setOpacity:psdLayer.opacity / 255.0f];
			
			NSPoint drawDelta = NSMakePoint(psdLayer.left, canvasSize.height - psdLayer.bottom);
			
			[layer setDrawDelta:drawDelta];
			
			CGImageRelease(imageRef);
		}
		
		CGContextRelease(context);
		free(outDest);
		
		
	}
	
	// free if it's done
	psd_image_free(pdfContext);
	
	if ([[[document baseGroup] layers] count] == 0) {
		return [self loadCompoisteForDocument:document fromURL:absoluteURL];
	}
	
	return YES;
#endif
}

- (NSNumber*) worksOnShapeLayers: (id) userObject
{
	return [NSNumber numberWithBool: NO];
}

@end
