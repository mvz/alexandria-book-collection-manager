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

@interface NSMatrix (Utils)

- (int)rowOfCell:(NSCell *)cell;
- (int)columnOfCell:(NSCell *)cell;
- (int)rowAtPoint:(NSPoint)point;
- (int)columnAtPoint:(NSPoint)point;
- (void)selectCellsInRect:(NSRect)rect;

@end

@interface NSImage (Utils)

+ (BOOL)isBlank:(NSString *)filename;

@end

@implementation NSMatrix (Utils)

- (int)rowOfCell:(NSCell *)cell
{
    int row, col;
    return ([self getRow:&row column:&col ofCell:cell]) ? row : -1;    
}

- (int)columnOfCell:(NSCell *)cell
{
    int row, col;
    return ([self getRow:&row column:&col ofCell:cell]) ? col : -1;    
}

- (int)rowAtPoint:(NSPoint)point
{
    int row, col;
    return ([self getRow:&row column:&col forPoint:point]) ? row : -1;    
}

- (int)columnAtPoint:(NSPoint)point
{
    int row, col;
    return ([self getRow:&row column:&col forPoint:point]) ? col : -1;    
}

- (void)selectCellsInRect:(NSRect)rect
{
    NSArray *cells;
    unsigned i, count;
    id cell;
    int row, col;
    
    cells = [self cells];
    for (i = 0, count = [cells count]; i < count; i++) {
        cell = [cells objectAtIndex:i];
        if ([self isEnabled] && [self getRow:&row column:&col ofCell:cell]) {
            if (NSIntersectsRect (rect, [self cellFrameAtRow:row column:col]))
                [cell setHighlighted:YES];
        }
    }
}

@end

@implementation NSImage (Utils)

+ (BOOL)isBlank:(NSString *)filename
{
    NSImage *   image;
    BOOL        blank;

    image = [[NSImage alloc] initWithContentsOfFile:filename];
    if ([image isValid]) {
        NSSize size = [image size];
        blank = size.width <= 1 && size.height <= 1;
    }
    else {
        blank = YES;
    }
    [image release];
    return blank;
}

@end
