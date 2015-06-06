/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASInsetLayoutNode.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASInternalHelpers.h"
#import "ASLayoutNodeSubclass.h"

@interface ASInsetLayoutNode ()
{
  UIEdgeInsets _insets;
  ASLayoutNode *_node;
}
@end

/* Returns f if f is finite, substitute otherwise */
static CGFloat finite(CGFloat f, CGFloat substitute)
{
  return isinf(f) ? substitute : f;
}

/* Returns f if f is finite, 0 otherwise */
static CGFloat finiteOrZero(CGFloat f)
{
  return finite(f, 0);
}

/* Returns the inset required to center 'inner' in 'outer' */
static CGFloat centerInset(CGFloat outer, CGFloat inner)
{
  return ASRoundPixelValue((outer - inner) / 2);
}

@implementation ASInsetLayoutNode

+ (instancetype)newWithInsets:(UIEdgeInsets)insets
                         node:(ASLayoutNode *)node
{
  if (node == nil) {
    return nil;
  }
  ASInsetLayoutNode *n = [super newWithSize:{}];
  if (n) {
    n->_insets = insets;
    n->_node = node;
  }
  return n;
}

+ (instancetype)newWithSize:(ASLayoutNodeSize)size
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

/**
 Inset will compute a new constrained size for it's child after applying insets and re-positioning
 the child to respect the inset.
 */
- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize
                          restrictedToSize:(ASLayoutNodeSize)size
                      relativeToParentSize:(CGSize)parentSize
{
  ASDisplayNodeAssert(ASLayoutNodeSizeEqualToNodeSize(size, ASLayoutNodeSizeZero),
           @"ASInsetLayoutNode only passes size {} to the super class initializer, but received size %@ "
           "(node=%@)", NSStringFromASLayoutNodeSize(size), _node);

  const CGFloat insetsX = (finiteOrZero(_insets.left) + finiteOrZero(_insets.right));
  const CGFloat insetsY = (finiteOrZero(_insets.top) + finiteOrZero(_insets.bottom));

  // if either x-axis inset is infinite, let child be intrinsic width
  const CGFloat minWidth = (isinf(_insets.left) || isinf(_insets.right)) ? 0 : constrainedSize.min.width;
  // if either y-axis inset is infinite, let child be intrinsic height
  const CGFloat minHeight = (isinf(_insets.top) || isinf(_insets.bottom)) ? 0 : constrainedSize.min.height;

  const ASSizeRange insetConstrainedSize = {
    {
      MAX(0, minWidth - insetsX),
      MAX(0, minHeight - insetsY),
    },
    {
      MAX(0, constrainedSize.max.width - insetsX),
      MAX(0, constrainedSize.max.height - insetsY),
    }
  };
  const CGSize insetParentSize = {
    MAX(0, parentSize.width - insetsX),
    MAX(0, parentSize.height - insetsY)
  };
  ASLayout *childLayout = [_node layoutThatFits:insetConstrainedSize parentSize:insetParentSize];

  const CGSize computedSize = ASSizeRangeClamp(constrainedSize, {
    finite(childLayout.size.width + _insets.left + _insets.right, parentSize.width),
    finite(childLayout.size.height + _insets.top + _insets.bottom, parentSize.height),
  });

  ASDisplayNodeAssert(!isnan(computedSize.width) && !isnan(computedSize.height),
           @"Inset node computed size is NaN; you may not specify infinite insets against a NaN parent size\n"
           "parentSize = %@, insets = %@", NSStringFromCGSize(parentSize), NSStringFromUIEdgeInsets(_insets));

  const CGFloat x = finite(_insets.left, constrainedSize.max.width -
                           (finite(_insets.right,
                                   centerInset(constrainedSize.max.width, childLayout.size.width)) + childLayout.size.width));

  const CGFloat y = finite(_insets.top,
                           constrainedSize.max.height -
                           (finite(_insets.bottom,
                                   centerInset(constrainedSize.max.height, childLayout.size.height)) + childLayout.size.height));
  return [ASLayout newWithNode:self
                          size:computedSize
                      children:@[[ASLayoutChild newWithPosition:{x,y} layout:childLayout]]];
}

@end