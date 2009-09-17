#import <Cocoa/Cocoa.h>

// pass in -DDEBUG to gcc in development builds to see some output when you 
// don't feel like using a debugger.

#ifdef DEBUG
#define debug(...) NSLog(__VA_ARGS__)
#else
#define debug(...)
#endif

enum {
    ACBitmapLayer = 1,
    ACShapeLayer = 2,
    ACGroupLayer = 3,
};

enum {
    ACRectangleGraphic = 1,
    ACOvalGraphic = 2,
    ACLineGraphic = 3,
    ACTextGraphic = 4,
    ACImageGraphic = 5,
    ACBezierGraphic = 6,
};

#define ACPLUGIN_SUPPORT 1

// forward decl.
@protocol ACBitmapTool;
@protocol ACImageIOProvider;

@protocol ACPluginManager

- (BOOL) addFilterMenuTitle:(NSString*)menuTitle
         withSuperMenuTitle:(NSString*)superMenuTitle
                     target:(id)target
                     action:(SEL)selector
              keyEquivalent:(NSString*)keyEquivalent
  keyEquivalentModifierMask:(NSUInteger)mask
                 userObject:(id)userObject;

- (BOOL) addActionMenuTitle:(NSString*)menuTitle
         withSuperMenuTitle:(NSString*)superMenuTitle
                     target:(id)target
                     action:(SEL)selector
              keyEquivalent:(NSString*)keyEquivalent
  keyEquivalentModifierMask:(NSUInteger)mask
                 userObject:(id)userObject;


// EXPERIMENTAL new in 1.1 
- (BOOL) addBitmapTool:(id<ACBitmapTool>)tool;

- (void) registerIOProviderForReading:(id<ACImageIOProvider>)provider forUTI:(NSString*)uti;
- (void) registerIOProviderForWriting:(id<ACImageIOProvider>)provider forUTI:(NSString*)uti;

@end

@protocol ACPlugin 

/*
 This will create an instance of our plugin.  You really shouldn't need to
 worry about this at all.
 */
+ (id) plugin;

/*
 This gets called right before the plugin manager registers your plugin.
 I'm honestly not sure what you would use it for, but it seemed like a good
 idea at the time.
 */
- (void) willRegister:(id<ACPluginManager>)thePluginManager;

/*
 didRegister is called right after your plugin is all ready to go.
 */
- (void) didRegister;

/*
 Can we handle shape layers?  If yes, then our action is handed the layer instead of a CIImage
 
 return [NSNumber numberWithBool:YES]; 
 
 NSNumber is used to be friendly with scripting languages.
 */
- (NSNumber*) worksOnShapeLayers:(id)userObject;

@end



@protocol ACLayer <NSObject>
/* There are currently three types of layers.  "Bitmap" layers which contain pixels,
 and "Shape" layers which contain Text.  And then Group layers, which is a group of layers.
 
 And maybe other things eventually.
 
 Check out the ACLayerType enum for the constants to tell which is which.
 */
- (int) layerType;

@property (assign) BOOL visible;
@property (assign) float opacity;
@end



@protocol ACShapeLayer <ACLayer>

- (NSArray *)selectedGraphics;
- (NSArray *)graphics;

- (id) addRectangleWithBounds:(NSRect)bounds;
- (id) addOvalWithBounds:(NSRect)bounds;
- (id) addTextWithBounds:(NSRect)bounds;

@end

@protocol ACBitmapLayer <ACLayer>

// set a CIImage on the layer, to be a "preview".  Make sure to set it to nil when you are
// done with whatever it is you are doing.
- (void) setPreviewCIImage:(CIImage*)img;

// apply a ciimage to the layer.
- (void) applyCIImageFromFilter:(CIImage*)img;

// grab a CIImage representation of the layer.
- (CIImage*)CIImage;


// EXPERIMENTAL new in 1.1 
// get a CGBitmapContext that we can draw on.
- (CGContextRef) drawableContext;

// EXPERIMENTAL new in 1.1 
// commit the changes we made to the context, for undo support
- (void) commitFrameOfDrawableContext:(NSRect)r;

// EXPERIMENTAL new in 1.1 
// find out where on our layer the current mouse event is pointing to
- (NSPoint) layerPointFromEvent:(NSEvent*)theEvent;

// EXPERIMENTAL new in 1.1 
// tell the layer it needs to be updated
- (void)setNeedsDisplayInRect:(NSRect)invalidRect;

@property (assign) NSPoint drawDelta;

@end

@protocol ACGroupLayer <ACLayer>

- (NSArray *)layers;

- (void) addLayer:(id<ACLayer>)l atIndex:(int)idx;

- (id<ACBitmapLayer>) insertCGImage:(CGImageRef)img atIndex:(NSUInteger)idx withName:(NSString*)layerName;

@end

@protocol ACGraphic <NSObject>

- (int) graphicType;

- (void)setDrawsFill:(BOOL)flag;
- (BOOL)drawsFill;

- (void)setFillColor:(NSColor *)fillColor;
- (NSColor *)fillColor;

- (void)setDrawsStroke:(BOOL)flag;
- (BOOL)drawsStroke;

- (void)setStrokeColor:(NSColor *)strokeColor;
- (NSColor *)strokeColor;

- (void)setStrokeLineWidth:(CGFloat)width;
- (CGFloat)strokeLineWidth;

- (NSRect)bounds;

- (BOOL)hasCornerRadius;
- (void)setHasCornerRadius:(BOOL)flag;

- (CGFloat)cornerRadius;
- (void)setCornerRadius:(CGFloat)newCornerRadius;

- (BOOL)hasShadow;
- (void)setHasShadow:(BOOL)flag;

- (CGFloat)shadowBlurRadius;
- (void)setShadowBlurRadius:(CGFloat)newShadowBlurRadius;

- (NSSize)shadowOffset;
- (void)setShadowOffset:(NSSize)newShadowOffset;

- (NSBezierPath *)bezierPath;

- (int) graphicType;

@end

@protocol ACDocument <NSObject> // this inherits from NSDocument

// grab an array of layers in the document.
- (NSArray*) layers;

// grab the current layer.
- (id<ACLayer>) currentLayer;

// crop to the given rect.
- (void) cropToRect:(NSRect)cropRect;

// scale the image to the given size.
- (void) scaleImageToSize:(NSSize)newSize;

- (void) scaleImageToHeight:(CGFloat)newHeight;
- (void) scaleImageToWidth:(CGFloat)newWidth;

// resize the image to the given size.
- (void) resizeImageToSize:(NSSize)newSize;

// find the size of the canvas
- (NSSize)canvasSize;
- (void) setCanvasSize:(NSSize)s;

// new in 2.0

// returns the base group, which contains all the base layers.
- (id<ACGroupLayer>) baseGroup;


- (NSSize)dpi;
- (void)setDpi:(NSSize)newDpi;


- (CGColorSpaceRef)colorSpace;
- (void)setColorSpace:(CGColorSpaceRef)newColorSpace;


@end

@protocol ACToolPalette <NSObject> 

- (NSColor *)frontColor;
- (void)setFrontColor:(NSColor *)newFrontColor;

- (NSColor *)backColor;
- (void)setBackColor:(NSColor *)newBackColor;

@end




// EXPERIMENTAL new in 1.1 
@protocol ACBitmapTool  <NSObject> 
- (void) mouseDown:(NSEvent*)theEvent onCanvas:(NSView*)canvas toLayer:(id<ACBitmapLayer>)layer;
- (NSCursor*) toolCursorAtScale:(CGFloat)scale;
- (NSString *) toolName;
- (NSView*) toolPaletteView;
@end


// EXPERIMENTAL new in 2.0
@protocol ACImageIOProvider  <NSObject> 

- (BOOL)writeDocument:(id<ACDocument>)document toURL:(NSURL *)absoluteURL ofType:(NSString *)type forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;

- (BOOL) readImageForDocument:(id<ACDocument>)document fromURL:(NSURL *)absoluteURL ofType:(NSString *)type error:(NSError **)outError;

@end



@interface NSApplication (AcornAdditions)

- (id<ACToolPalette>) toolPalette;

@end





/*
 CTGradient is in Acorn, it's just got a different name- "TSGradient".
 For more info on CTGradient, visit here:
 http://blog.oofn.net/2006/01/15/gradients-in-cocoa/
 
 You can use it like so:
 id fade = [NSClassFromString(@"TSGradient") gradientWithBeginningColor:[NSColor clearColor] endingColor:[NSColor blackColor]];
 */
@interface NSObject (TSGradientTrustMeItsThere)
+ (id)gradientWithBeginningColor:(NSColor *)begin endingColor:(NSColor *)end;
- (void)fillRect:(NSRect)rect angle:(CGFloat)angle;
@end

@interface CIImage (PXNSImageAdditions)
- (NSImage *)NSImageFromRect:(CGRect)r;
- (NSImage *)NSImage;
@end

@interface NSDocumentController (ACNSDocumentControllerAdditions)
- (id) newDocumentWithImageData:(NSData*)data;
@end
