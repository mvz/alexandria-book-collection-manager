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

@interface TitledImageCell : NSTextFieldCell
{
    NSString *  _title;
    NSRect      _titleFrame;
    NSImage *   _image;
}
@end

static NSString *   _ellipsis = nil;

@implementation TitledImageCell

+ (void)initialize
{
    if (self == [TitledImageCell class]) {
        const unichar ellipsisChar = 0x2026;
        _ellipsis = [[NSString stringWithCharacters:&ellipsisChar length:1] retain];
    }
}

- (id)init
{
    self = [super initTextCell:@""];
    if (self == nil)
        return nil;
        
    [self setEditable:YES];
    [self setDrawsBackground:YES];
    [self setBackgroundColor:[NSColor whiteColor]];
        
    _title = nil;
    _titleFrame = NSZeroRect;
    _image = nil;    

    return self;
}

- (void)dealloc
{
    [_title release];
    [_image release];
    [super dealloc];
}

- (void)setObjectValue:(id)objectValue
{
    if ([objectValue isKindOfClass:[NSArray class]]
        && [objectValue count] == 2) {

        //[_title release];
        //[_image release];

        _title = [[objectValue objectAtIndex:0] retain];
        _image = [[objectValue objectAtIndex:1] retain];
        
        NSAttributedString *attString = [[NSAttributedString alloc] initWithString:_title];
        [self setAttributedStringValue:attString];
        [attString release];
    }
    else if ([objectValue isKindOfClass:[NSAttributedString class]]) {
        [super setObjectValue:objectValue];
    }
}

- (id)objectValue
{
    return [NSArray arrayWithObjects:_title, _image, nil];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)view
{
    NSPoint drawPoint;
    float x;

    x = 0;

    // draw image
    if (_image != nil) {    
        NSSize iconSize = [_image size];
        drawPoint = NSMakePoint(NSMinX (cellFrame), round (NSMaxY (cellFrame) - (NSHeight (cellFrame) - iconSize.height) / 2) - 1.0);
        [_image compositeToPoint:drawPoint operation:NSCompositeSourceOver];
        
        x += iconSize.width + 5;
    }

    // draw title
	_titleFrame = cellFrame;
	_titleFrame.origin.x += x;
	_titleFrame.size.width -= x + 5;
	_titleFrame.origin.y += 1;
	_titleFrame.size.height -= 2;

    NSColor *textColor = [self isHighlighted] && [[view window] firstResponder] == view && [[view window] isKeyWindow]? [NSColor whiteColor] : [NSColor blackColor];
    
	NSDictionary * attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[self font], NSFontAttributeName,
		textColor, NSForegroundColorAttributeName,
		nil];

    NSRange     truncatedRange = NSMakeRange(0, [_title length]);
    NSSize      truncatedSize;
    NSString *  truncatedTitle;
    NSSize      ellipsisSize = [_ellipsis sizeWithAttributes:attributes];
    
    do {
        truncatedTitle = [_title substringWithRange:truncatedRange];
        truncatedSize = [truncatedTitle sizeWithAttributes:attributes];
        if (truncatedSize.width + ellipsisSize.width > NSWidth (_titleFrame)) {
            truncatedRange.length--;
        }
        else {
            break;
        }
    }
    while (YES);

    if (truncatedRange.length < [_title length])
        truncatedTitle = [truncatedTitle stringByAppendingString:_ellipsis];

	[truncatedTitle drawInRect:_titleFrame withAttributes:attributes];
}

- (NSRect)_preparedFrameForEdition:(NSRect)frame
{
    frame = _titleFrame;
    frame.origin.x = _titleFrame.origin.x - 2;
    frame.size.width = _titleFrame.size.width + 6;
    return frame;
}

- (void)editWithFrame:(NSRect)frame inView:(NSView *)controlView 
                                    editor:(NSText *)editor 
                                    delegate:(id)delegate 
                                    event:(NSEvent *)theEvent
{
    frame = [self _preparedFrameForEdition:frame];
    
	[super editWithFrame:frame 
           inView:controlView 
           editor:editor 
           delegate:delegate 
           event:theEvent];
}

- (void)selectWithFrame:(NSRect)frame inView:(NSView *)controlView
                                      editor:(NSText *)editor 
                                      delegate:(id)delegate 
                                      start:(int)selStart 
                                      length:(int)selLength
{
    frame = [self _preparedFrameForEdition:frame];
    
	[super selectWithFrame:frame 
           inView:controlView 
           editor:editor 
           delegate:delegate 
           start:selStart
           length:selLength];
}

- (void)endEditing:(NSText *)textObj
{
    [_title release];
    _title = [[textObj string] retain];

	[super endEditing:textObj];
}

@end