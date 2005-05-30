// Copyright (C) 2005 Laurent Sansonetti
//
// Alexandria is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as
// published by the Free Software Foundation; either version 2 of the
// License, or (at your option) any later version.
//
// Alexandria is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with Alexandria; see the file COPYING.  If not,
// write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
// Boston, MA 02111-1307, USA.

#import <Cocoa/Cocoa.h>

@interface RatingCell : NSImageCell
{
    unsigned _value;
}

@end

@interface RatingCell (Private)

- (NSImage *)_generateImage;

@end

static NSImage *                _starSetImage = nil;
static NSImage *                _starUnsetImage = nil;
static NSMutableDictionary *    _starCache = nil;

@implementation RatingCell

+ (void)setStarSetImage:(NSImage *)starSetImage
{
    @synchronized (self) {
        if (_starSetImage != starSetImage) {
            [_starSetImage release];
            _starSetImage = [starSetImage retain];
        }
    }
}

+ (void)setStarUnsetImage:(NSImage *)starUnsetImage
{
    @synchronized (self) {
        if (_starUnsetImage != starUnsetImage) {
            [_starUnsetImage release];
            _starUnsetImage = [starUnsetImage retain];
        }
    }
}

- (id)init
{
    self = [super initImageCell:nil];
    if (self == nil)
        return nil;
    
    _value = 0;

    [self setImageAlignment:NSImageAlignLeft];
    [self setImageScaling:NSScaleNone];
    
    return self;
}

- (void)setObjectValue:(id)objectValue
{
    NSImage *image;
    if ([objectValue isKindOfClass:[NSNumber class]]) {
        _value = [objectValue unsignedIntValue];
        @synchronized (self) {
            if (_starCache == nil) {
                _starCache = [[NSMutableDictionary alloc] init];
            }
            image = [_starCache objectForKey:objectValue];
            if (image == nil) {
                image = [self _generateImage];
                [_starCache setObject:image forKey:objectValue];
            }
        }
        [super setObjectValue:image];
    }
}

- (id)objectValue
{
    return [NSNumber numberWithUnsignedInt:_value];
}

+ (unsigned)valueForPoint:(NSPoint)point
{
    NSSize starSize;

    NSAssert (_starSetImage != nil, @"starSetImage not set");
    NSAssert (_starUnsetImage != nil, @"starUnsetImage not set");

    starSize = [_starSetImage size];
    if (point.x <= 10)
        return 0;
    if (point.x >= (5 * starSize.width) + 10)
        return 5;
    return ceil ((point.x - 10) / starSize.width);
}

- (NSImage *)_generateImage
{
    NSImage *image;
    NSSize starSize;
    unsigned i;
    NSPoint point;

    NSAssert (_starSetImage != nil, @"starSetImage not set");
    NSAssert (_starUnsetImage != nil, @"starUnsetImage not set");
    
    starSize = [_starSetImage size];
    
    image = [[NSImage alloc] initWithSize:NSMakeSize ((starSize.width * 5) + 20, 
                                                      starSize.height)];
    [image lockFocus];
    
    for (i = 0, point = NSMakePoint(10, 0); i < 5; i++, point.x += starSize.width) {
        [i >= _value ? _starUnsetImage : _starSetImage compositeToPoint:point operation:NSCompositeSourceOver];
    }
    
    [image unlockFocus];

    return [image autorelease];
}

@end