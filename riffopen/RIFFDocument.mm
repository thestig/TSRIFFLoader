//
//  RIFFDocument.mm
//  riffloader
//
//  Created by The Stig on 09-09-17.
//  Copyright 2009 The Stig. All rights reserved.
//

#import "RIFFDocument.h"
#import <Renderer/Renderer.h>
#import <RiffIO/RiffIO.h>
#import <fstream>

// C++ Interface to read RIFF files
class RIFFDataStream : public IDataStream
{
	std::fstream _stream;
public:
	RIFFDataStream(const char* filename, std::ios_base::openmode mode)
	{
		_stream.open(filename, mode);
	}
	void release()
	{
		delete this;
	}

	void read(void *buffer, int count)
	{
		_stream.read((char*)buffer, count);
	}
	void write(void *buffer, int count)
	{
		_stream.write((char*)buffer, count);
	}

	void seek(int pos, std::ios_base::seekdir base)
	{
		_stream.seekg(pos, base);
	}
	int tellg()
	{
		return _stream.tellg();
	}

	bool fail()
	{
		return _stream.fail();
	}
	void clear()
	{
		_stream.clear();
	}
};


@implementation RIFFDocument

// Properties
@synthesize width = _width;
@synthesize height = _height;
@synthesize layerCount = _layerCount;
@synthesize resolution = _resolution;

- (void) countLayers
{
	IRiffDocument* riffDocument;
	_layerCount = 0;
	_resolution = 72.0;
	
	riffDocument = riffOpenFile(new RIFFDataStream([_filepath UTF8String], std::ios_base::binary | std::ios_base::in));
	
	RIFF_Error err = riffDocument->valid();
	if (RIFF_NOERR == err)
	{
		riffDocument->getNumLayers(_layerCount);
		riffDocument->getDimensions(_height, _width);
		riffDocument->getResolution(_resolution);
	}
	riffDocument->release();
}

- (id) initWithFile: (NSString*) filepath
{
	if (self = [super init])
	{
		[_filepath release];
		[filepath retain];
		_filepath = filepath;
		[self countLayers];
	}
	return self;
}

- (IRiffDocument*) openRIFFFile
{
	IRiffDocument *riffDocument = riffOpenFile(new RIFFDataStream([_filepath UTF8String], std::ios_base::binary | std::ios_base::in));
	
	RIFF_Error err = riffDocument->valid();
	if (RIFF_NOERR != err)
		return nil;
	
	return riffDocument;
}

- (CGColorSpaceRef) RGBColorSpace
{
	if (NULL == _deviceRGB)
		_deviceRGB = CGColorSpaceCreateDeviceRGB();
	return _deviceRGB;
}

- (CGImageRef) getImageFromRiffBinaryData: (IRiffBinaryData*) riffData
															 pixelsWide: (int) w 
															 pixelsHigh: (int) h
															invertAlpha: (BOOL) invert
{
	// Painter is 32 bit ARGB
	const int kPixelSize = 4;
	const int kBestByteAlignment = 16;
	int rowBytes = w * kPixelSize;
	
	// Round up to nearest multiple of kBestByteAlignment
	rowBytes = (((rowBytes) + (kBestByteAlignment - 1)) & ~(kBestByteAlignment - 1));
	
	unsigned char* rasterData = static_cast<unsigned char*>(calloc(1, rowBytes * h));
	if (NULL == rasterData)
	{
		//NSLog(@"calloc: could not allocate %d bytes", rowBytes * h);
		return NULL;
	}
	
	unsigned char* destData = rasterData;
	riffData->resetScanLines();
	
	for (int i = 0; i < h; i++)
	{
		unsigned long* realData = (unsigned long*)(destData + i * rowBytes);
		riffData->getNextScanLine((char *)realData);
		for (int j = 0; j < w; j++)
		{
			int alpha = 0xff;
			int rgb = ((*realData) & 0x00FFFFFF);
			if (invert)
			{
				// Invert the alpha if needed
				alpha = (*realData) >> 24;
				alpha = 0xFF - alpha; 
			}
			// Premultiply rgb values
			float fAlpha = alpha / 255.0f;
			float fRed = ((rgb & 0x00FF0000) >> 16) * fAlpha;
			float fGreen = ((rgb & 0x0000FF00) >> 8) * fAlpha;
			float fBlue = (rgb & 0x000000FF) * fAlpha;
			unsigned char red = fRed;
			unsigned char green = fGreen;
			unsigned char blue = fBlue;
			// Recombine and byteswap if necessary
			(*realData) = CFSwapInt32BigToHost((alpha << 24) + (red << 16) + (green << 8) + blue);
			realData++;
		}
	}
	
	CGContextRef context = CGBitmapContextCreate(rasterData, w, h, 8, rowBytes, [self RGBColorSpace], kCGImageAlphaPremultipliedFirst);
	if (NULL == context)
	{
		free(rasterData);
		//NSLog(@"Unable to create context");
		return NULL;
	}
	
	CGImageRef destImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	return destImage;
}

// Map the Painter "merge modes" to CGBlendMode to the best of our abilities
- (CGBlendMode) getCGBlendMode: (short) riffMergeMode
{
	CGBlendMode mode = kCGBlendModeNormal;
	switch (riffMergeMode)
	{
		case Renderer::MergeModes::alg_opacity:
		case Renderer::MergeModes::alg_normal:
			mode = kCGBlendModeNormal;
			break;
			
		case Renderer::MergeModes::alg_darken:
			mode = kCGBlendModeDarken;
			break;
			
		case Renderer::MergeModes::alg_lighten:
			mode = kCGBlendModeLighten;
			break;
			
		case Renderer::MergeModes::alg_multiply:
			mode = kCGBlendModeMultiply;
			break;
			
		case Renderer::MergeModes::alg_screen:
			mode = kCGBlendModeScreen;
			break;
			
		case Renderer::MergeModes::alg_overlay:
			mode = kCGBlendModeOverlay;
			break;
			
		case Renderer::MergeModes::alg_soft_light:
			mode = kCGBlendModeSoftLight;
			break;
			
		case Renderer::MergeModes::alg_hard_light:
			mode = kCGBlendModeHardLight;
			break;
			
		case Renderer::MergeModes::alg_difference:
			mode = kCGBlendModeDifference;
			break;
			
		case Renderer::MergeModes::alg_hue:
			mode = kCGBlendModeHue;
			break;
			
		case Renderer::MergeModes::alg_saturation:
			mode = kCGBlendModeSaturation;
			break;
			
		case Renderer::MergeModes::alg_color:
			mode = kCGBlendModeColor;
			break;
			
		case Renderer::MergeModes::alg_luminosity:
			mode = kCGBlendModeLuminosity;
			break;
			
		case Renderer::MergeModes::alg_dye_absorption:
			mode = kCGBlendModeMultiply;
			break;
			
		case Renderer::MergeModes::alg_reverse_out:
			mode = kCGBlendModeExclusion;
			break;
			
		default:
			mode = kCGBlendModeNormal;
			break;
	}
	
	return mode;
}

- (CGImageRef) copyLayer: (int) layer 
               isVisible: (BOOL*) visible 
             layerOffset: (CGPoint*) offset 
            layerOpacity: (double*) opacity 
               blendMode: (CGBlendMode*) mode
               layerName: (NSString**) lyrName

{
	IRiffDocument* riffDocument = [self openRIFFFile];
	if (!riffDocument)
		return nil;
	
	IRiffLayer* riffLayer = riffDocument->getNthLayer(layer);
	if (!riffLayer)
		return nil;
	
	short h, w;
	RIFF_Layer_Properties layer_properties;
	riffLayer->getLayerProperties(layer_properties);
	riffLayer->getDimensions(h, w);
	if (offset)
	{
		int x, y;
		riffLayer->getOrigin(x, y);
		offset->x = x;
		offset->y = y;
	}
	if (opacity)
	{
		riffLayer->getOpacity(*opacity);
	}
	if (visible)
	{
		*visible = !(layer_properties.flags & kFlagLayerIsInvisible);
	}
	if (mode)
	{
		*mode = [self getCGBlendMode: layer_properties.algorithm];
	}
	if (lyrName)
	{
		if (layer_properties.name[0] > 0)
		{
			// Ensure null-terminated string
			short len = layer_properties.name[0] + 1;
			if (len > 0xFF)
				len = 0xFF;
			layer_properties.name[len] = 0;
			*lyrName = [NSString stringWithCString:(char *)(layer_properties.name + 1) encoding: NSMacOSRomanStringEncoding];
		}
		else 
		{
			*lyrName = [NSString stringWithString: @"Canvas"];
		}

	}
	
	IRiffBinaryData* riffData = riffLayer->getCombinedData(false);
	if (!riffData)
		return nil;
	
	// alpha channel in Painter has opposite meaning of Quartz, so invert it on layers
	CGImageRef layerImage = [self getImageFromRiffBinaryData: riffData pixelsWide: w pixelsHigh: h invertAlpha: (0 != layer)];
	
	riffDocument->release();
	
	return layerImage;
}

@end
