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

@interface BookIconCell : NSTextFieldCell
{
    NSImage *   _bookCover;
    NSString *  _bookTitle;
    NSString *  _truncatedBookTitle;
    unsigned    _borderWidth;
}

@end

@interface BookIconCell (Private)

- (void)_truncateTitleToFitInRect:(NSRect)rect;
- (NSDictionary *)_drawingAttributes;

@end

static NSString *       _ellipsis;

@implementation BookIconCell

+ (void)initialize
{
     if (self == [BookIconCell class]) {	 
         const unichar ellipsisChar = 0x2026;	 
         _ellipsis = [[NSString stringWithCharacters:&ellipsisChar length:1] retain];
     }	
}

- (id)init
{
    self = [super initTextCell:@""];
    if (self == nil)
        return nil;
        
    _bookCover = nil;
    _bookTitle = nil;
    _truncatedBookTitle = nil;

    [self setEditable:NO];
    [self setFont:[NSFont fontWithName:@"Lucida Grande" size:10.0]];
    [self setAlignment:NSCenterTextAlignment];
    [self setWraps:YES];
    
    _borderWidth = 8;   // XXX: not used ATM

    return self;
}

- (void)dealloc
{
    [_bookCover release];
    [_bookTitle release];
    [_truncatedBookTitle release];

    [super dealloc];
}

- (void)setBookTitle:(NSString *)bookTitle
{
    if (bookTitle != _bookTitle) {
        [_bookTitle release];
        _bookTitle = [bookTitle retain];

        [_truncatedBookTitle release];
        _truncatedBookTitle = nil;
    }
}

- (NSString *)bookTitle
{
    return _bookTitle;
}

- (void)setBookCover:(NSImage *)bookCover
{
    if (bookCover != _bookCover) {
        [_bookCover release];
        _bookCover = [bookCover retain];        
    }
}

- (NSImage *)bookCover
{
    return _bookCover;
}

- (void)setObjectValue:(id)objectValue
{
    if ([objectValue isKindOfClass:[NSArray class]]
        && [objectValue count] == 2) {

        [self setBookCover:[objectValue objectAtIndex:0]];
        [self setBookTitle:[objectValue objectAtIndex:1]];
    }
    else if (objectValue == nil) {
        [self setBookCover:nil];
        [self setBookTitle:nil];
    }
    else {
        [super setObjectValue:objectValue];
    }
}

- (id)objectValue
{
    return _bookCover == nil || _bookTitle == nil ? nil : [NSArray arrayWithObjects:_bookCover, _bookTitle, nil];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)view
{
    float y = 0;
    
    if (![self isEnabled] || _bookTitle == nil)
        return;

    // draw cover
    if (_bookCover != nil) {
        NSSize iconSize = [_bookCover size];
        NSPoint drawPoint = NSMakePoint(NSMinX (cellFrame), [view isFlipped] ? round (NSMaxY (cellFrame) - (NSHeight (cellFrame) - iconSize.height)) : NSHeight (cellFrame) - iconSize.height);
        [_bookCover compositeToPoint:drawPoint operation:NSCompositeSourceOver];
        y += iconSize.height + 5;
    }
    
    // draw title
    cellFrame.origin.y += y;
    cellFrame.size.height = 25;
        
    if (_truncatedBookTitle == nil)
        [self _truncateTitleToFitInRect:cellFrame];
    [super drawWithFrame:cellFrame inView:view];
    
    //[[NSColor redColor] set];
    //NSFrameRect(cellFrame);
}

- (NSDictionary *)_drawingAttributes
{    
    NSMutableParagraphStyle *paragraphStyle;
    
    paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [paragraphStyle setLineBreakMode:[self lineBreakMode]];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
                            [self font], NSFontAttributeName,
                            paragraphStyle, NSParagraphStyleAttributeName,
                            nil];
}

- (void)_truncateTitleToFitInRect:(NSRect)rect
{
    NSDictionary *          attributes;
    NSRange                 truncatedRange;	 
    NSSize                  ellipsisSize;	 
    NSLayoutManager *       layoutManager;
    NSTextContainer *       textContainer;
    NSTextStorage *         textStorage;
    NSAttributedString *    attributedText;
    unsigned                glyphCount;
    NSRect                  boundingRect;

    [_truncatedBookTitle release];
    _truncatedBookTitle = nil;

    if (_bookTitle == nil)
        return;
  	 
    attributes = [self _drawingAttributes];
    truncatedRange = NSMakeRange(0, [_bookTitle length]);	 
    ellipsisSize = [_ellipsis sizeWithAttributes:attributes];	 

    layoutManager = [[NSLayoutManager alloc] init];
    textContainer = [[NSTextContainer alloc] init];
    textStorage = [[NSTextStorage alloc] init];

    [textContainer setContainerSize:NSMakeSize (NSWidth(rect), INFINITY)];
    
    [layoutManager addTextContainer:textContainer];
    [textContainer release];

    [textStorage addLayoutManager:layoutManager];

    do {
        _truncatedBookTitle = [_bookTitle substringWithRange:truncatedRange];
        if (truncatedRange.length < [_bookTitle length])	 
            _truncatedBookTitle = [_truncatedBookTitle stringByAppendingString:_ellipsis];	

        attributedText = [[NSAttributedString alloc] initWithString:_truncatedBookTitle attributes:attributes];
        [textStorage setAttributedString:attributedText];
        [attributedText release];
    
        glyphCount = [layoutManager numberOfGlyphs];
        if (glyphCount == 0)
            break;

        boundingRect = [layoutManager boundingRectForGlyphRange:NSMakeRange (0, [layoutManager numberOfGlyphs])
                                      inTextContainer:textContainer];

        if (NSHeight(rect) >= NSHeight(boundingRect))
            break;

        truncatedRange.length--;	         
    }
    while (YES);

    [layoutManager release];
    [textStorage release];

    [_truncatedBookTitle retain];
    
    [self setStringValue:_truncatedBookTitle];
}

@end
