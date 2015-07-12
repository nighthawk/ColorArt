//
//  SLColorArt.m
//  ColorArt
//
//  Created by Aaron Brethorst on 12/11/12.
//
// Copyright (C) 2012 Panic Inc. Code by Wade Cosgrove. All rights reserved.
//
// Redistribution and use, with or without modification, are permitted provided that the following conditions are met:
//
// - Redistributions must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//
// - Neither the name of Panic Inc nor the names of its contributors may be used to endorse or promote works derived from this software without specific prior written permission from Panic Inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL PANIC INC BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import "SLColorArt.h"
#import "UIImage+Scale.h"
#define kAnalyzedBackgroundColor @"kAnalyzedBackgroundColor"


@interface PCCountedColor : NSObject

@property (assign) NSUInteger count;
@property (strong) UIColor *color;

- (id)initWithColor:(UIColor*)color count:(NSUInteger)count;

@end

@interface SLColorArt ()
@property(nonatomic, copy) UIImage *image;
@property(nonatomic,readwrite,strong) UIColor *backgroundColor;
@property(nonatomic,readwrite) NSInteger randomColorThreshold;
@end

@implementation SLColorArt

- (id)initWithImage:(UIImage*)image
{
    self = [self initWithImage:image threshold:2];
    if (self) {

    }
    return self;
}

- (id)initWithImage:(UIImage*)image threshold:(NSInteger)threshold;
{
    self = [super init];

    if (self)
    {
        self.randomColorThreshold = threshold;
        self.image = image;
        [self _processImage];
    }

    return self;
}


+ (void)processImage:(UIImage *)image
        scaledToSize:(CGSize)scaleSize
           threshold:(NSInteger)threshold
          onComplete:(void (^)(SLColorArt *colorArt))completeBlock;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *scaledImage = [image scaledToSize:scaleSize];
        SLColorArt *colorArt = [[SLColorArt alloc] initWithImage:scaledImage
                                                       threshold:threshold];
        dispatch_async(dispatch_get_main_queue(), ^{
            completeBlock(colorArt);
        });
    });
    
}

- (void)_processImage
{
    self.backgroundColor = [self _analyzeImage:self.image];
}

- (UIImage*)_scaleImage:(UIImage*)image size:(CGSize)scaledSize
{
    return [image scaledToSize:scaledSize];
}

- (UIColor *)_analyzeImage:(UIImage*)anImage
{
    NSArray *imageColors = nil;
	UIColor *backgroundColor = [self _findEdgeColor:anImage imageColors:&imageColors];
  
    // If the random color threshold is too high and the image size too small,
    // we could miss detecting the background color and crash.
    if (backgroundColor == nil) {
        backgroundColor = [UIColor whiteColor];
    }
    return backgroundColor;
}

typedef struct RGBAPixel
{
    Byte red;
    Byte green;
    Byte blue;
    Byte alpha;
    
} RGBAPixel;

- (UIColor*)_findEdgeColor:(UIImage*)image imageColors:(NSArray**)colors
{
	CGImageRef imageRep = image.CGImage;
    
    NSUInteger pixelRange = 8;
    NSUInteger scale = 256 / pixelRange;
    NSUInteger rawImageColors[pixelRange][pixelRange][pixelRange];
    NSUInteger rawEdgeColors[pixelRange][pixelRange][pixelRange];
    
    // Should probably just switch to calloc, but this doesn't show up in instruments
    // So I guess it's fine
    for(NSUInteger b = 0; b < pixelRange; b++) {
        for(NSUInteger g = 0; g < pixelRange; g++) {
            for(NSUInteger r = 0; r < pixelRange; r++) {
                rawImageColors[r][g][b] = 0;
                rawEdgeColors[r][g][b] = 0;
            }
        }
    }
    

    NSInteger width = CGImageGetWidth(imageRep);// [imageRep pixelsWide];
	NSInteger height = CGImageGetHeight(imageRep); //[imageRep pixelsHigh];

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef bmContext = CGBitmapContextCreate(NULL, width, height, 8, 4 * width, cs, kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = width, .size.height = height}, image.CGImage);
    CGColorSpaceRelease(cs);
    const RGBAPixel* pixels = (const RGBAPixel*)CGBitmapContextGetData(bmContext);
    
    NSUInteger edgeSpacing = 8;
    NSUInteger edgeWidth = 16;
    
    for (NSUInteger y = edgeSpacing; y < height - edgeSpacing; y++)
    {
        for (NSUInteger x = edgeSpacing; x < width - edgeSpacing; x++)
        {
            const NSUInteger index = x + y * width;
            RGBAPixel pixel = pixels[index];
            Byte r = pixel.red / scale;
            Byte g = pixel.green / scale;
            Byte b = pixel.blue / scale;
//            rawImageColors[r][g][b] = rawImageColors[r][g][b] + 1;
            if((x <= edgeSpacing + edgeWidth || x >= width - edgeSpacing - edgeWidth)
               && (y <= edgeSpacing + edgeWidth || y >= height - edgeSpacing - edgeWidth)) {
                rawEdgeColors[r][g][b] = rawEdgeColors[r][g][b] + 1;
            }
        }
    }
    CGContextRelease(bmContext);

    NSMutableArray* imageColors = [NSMutableArray array];
    NSMutableArray* edgeColors = [NSMutableArray array];
    
    for(NSUInteger b = 0; b < pixelRange; b++) {
        for(NSUInteger g = 0; g < pixelRange; g++) {
            for(NSUInteger r = 0; r < pixelRange; r++) {
//                NSUInteger count = rawImageColors[r][g][b];
//                if(count > _randomColorThreshold) {
//                    UIColor* color = [UIColor colorWithRed:r / (CGFloat)pixelRange green:g / (CGFloat)pixelRange blue:b / (CGFloat)pixelRange alpha:1];
//                    PCCountedColor* countedColor = [[PCCountedColor alloc] initWithColor:color count:count];
//                    [imageColors addObject:countedColor];
//                }
                
                NSUInteger edgeCount = rawEdgeColors[r][g][b];
                if(edgeCount > _randomColorThreshold) {
                    UIColor* color = [UIColor colorWithRed:r / (CGFloat)pixelRange green:g / (CGFloat)pixelRange blue:b / (CGFloat)pixelRange alpha:1];
                    PCCountedColor* countedColor = [[PCCountedColor alloc] initWithColor:color count:edgeCount];
                    [edgeColors addObject:countedColor];
                }
            }
        }
    }

	*colors = imageColors;
    
    NSMutableArray* sortedColors = edgeColors;
	[sortedColors sortUsingSelector:@selector(compare:)];

	PCCountedColor *proposedEdgeColor = nil;

	if ( [sortedColors count] > 0 )
	{
		proposedEdgeColor = [sortedColors objectAtIndex:0];

	}

	return proposedEdgeColor.color;
}


@end



@implementation PCCountedColor

- (id)initWithColor:(UIColor*)color count:(NSUInteger)count
{
	self = [super init];

	if ( self )
	{
		self.color = color;
		self.count = count;
	}

	return self;
}

- (NSComparisonResult)compare:(PCCountedColor*)object
{
	if ( [object isKindOfClass:[PCCountedColor class]] )
	{
		if ( self.count < object.count )
		{
			return NSOrderedDescending;
		}
		else if ( self.count == object.count )
		{
			return NSOrderedSame;
		}
	}
    
	return NSOrderedAscending;
}


@end
