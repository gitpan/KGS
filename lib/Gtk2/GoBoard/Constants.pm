package Gtk2::GoBoard::Constants;

use base Exporter;

@EXPORT = qw(
   MARK_TRIANGLE MARK_SQUARE MARK_CIRCLE MARK_SMALL_B MARK_SMALL_W MARK_B
   MARK_W MARK_GRAYED MARK_MOVE MARK_LABEL MARK_HOSHI
   MARK_REDRAW
);

# marker types for each board position (ORed together)

sub MARK_TRIANGLE (){ 0x0001 }
sub MARK_SQUARE   (){ 0x0002 }
sub MARK_CIRCLE   (){ 0x0004 }
sub MARK_SMALL_B  (){ 0x0008 }
sub MARK_SMALL_W  (){ 0x0010 }
sub MARK_B        (){ 0x0020 }
sub MARK_W        (){ 0x0040 }
sub MARK_GRAYED   (){ 0x0080 }
sub MARK_LABEL    (){ 0x0100 }
sub MARK_HOSHI    (){ 0x0200 }
sub MARK_MOVE     (){ 0x0400 }
sub MARK_REDRAW   (){ 0x0800 }

1;

