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

@end