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
    NSImage *   _image;
}
@end

@implementation TitledImageCell

- (id)init
{
    self = [super initTextCell:@""];
    if (self == nil)
        return nil;
        
    [self setEditable:YES];
    [self setLineBreakMode:NSLineBreakByTruncatingTail];
        
    _title = nil;
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
        
        [self setStringValue:_title];
    }
    else if ([objectValue isKindOfClass:[NSString class]]) {
        [super setObjectValue:objectValue];
    }
}

- (id)objectValue
{
    return [NSArray arrayWithObjects:_title, _image, nil];
}

- (NSRect)_frameForTitle:(NSRect)cellFrame
{
    if (_image != nil) {
        const float x = [_image size].width + 2;
        cellFrame.origin.x += x;
        cellFrame.size.width -= x;
    }
    return cellFrame;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)view
{
    // draw image
    if (_image != nil) {    
        NSSize iconSize = [_image size];
        NSPoint drawPoint = NSMakePoint(NSMinX (cellFrame), round (NSMaxY (cellFrame) - (NSHeight (cellFrame) - iconSize.height) / 2) - 1.0);
        [_image compositeToPoint:drawPoint operation:NSCompositeSourceOver];
    }

    // draw title
    [super drawWithFrame:[self _frameForTitle:cellFrame] inView:view];
}

- (void)editWithFrame:(NSRect)frame inView:(NSView *)controlView 
                                    editor:(NSText *)editor 
                                    delegate:(id)delegate 
                                    event:(NSEvent *)theEvent
{
	[super editWithFrame:[self _frameForTitle:frame] 
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
	[super selectWithFrame:[self _frameForTitle:frame] 
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