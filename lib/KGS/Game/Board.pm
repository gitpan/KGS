package KGS::Game::Board;

use Gtk2::GoBoard::Constants;

use KGS::Constants;

sub new {
   my $class = shift;
   my $size = shift;
   bless {
         max      => $size - 1,
         board    => [map [(0) x $size], 1 .. $size],
         captures => [0, 0], # captures
         time     => [],
      },
      $class;
}

# inefficient and primitive, I hear you say?
# well... you are right :)
# use an extremely dumb floodfill algorithm to get rid of captured stones
sub capture {
   my ($self, $mark, $x, $y) = @_;

   my %seen;
   my @found;
   my @nodes = ([$x,$y]);

   while (@nodes) {
      my ($x, $y) = @{pop @nodes};
      unless ($seen{"$x,$y"}++) {
         if ($self->{board}[$x][$y] & $mark) {
            push @found, [$x, $y];

            push @nodes, [$x-1, $y] if $x > 0;
            push @nodes, [$x+1, $y] if $x < $self->{max};
            push @nodes, [$x, $y-1] if $y > 0;
            push @nodes, [$x, $y+1] if $y < $self->{max};
         } elsif (!($self->{board}[$x][$y] & (MARK_B | MARK_W))) {
            return;
         }
      }
   }

   $self->{captures}[ $mark == MARK_B ? COLOUR_WHITE : COLOUR_BLACK ] += @found;

   # capture!
   for (@found) {
      my ($x, $y) = @$_;
      $self->{board}[$x][$y] &= ~(MARK_B | MARK_W | MARK_MOVE);
   }
}

sub capture4 {
   my ($self, $mark, $x, $y) = @_;

   $self->capture($mark, $x-1, $y) if $x > 0            && $self->{board}[$x-1][$y] & $mark;
   $self->capture($mark, $x+1, $y) if $x < $self->{max} && $self->{board}[$x+1][$y] & $mark;
   $self->capture($mark, $x, $y-1) if $y > 0            && $self->{board}[$x][$y-1] & $mark;
   $self->capture($mark, $x, $y+1) if $y < $self->{max} && $self->{board}[$x][$y+1] & $mark;
}

sub interpret_path {
   my ($self, $path) = @_;

   my $move;

   $self->{last}    = COLOUR_BLACK; # black always starts.. ehrm..
   $self->{curnode} = $path->[-1];

   for (@$path) {
      # mask out all labeling except in the last node
      my $nodemask = ~(
            $_ == $path->[-1]
               ? 0
               : MARK_SQUARE | MARK_TRIANGLE | MARK_CIRCLE | MARK_LABEL
         );
               
      while (my ($k, $v) = each %$_) {
         if ($k =~ /^(\d+),(\d+)$/) {
            $self->{board}[$1][$2] =
               $self->{board}[$1][$2]
               & ~$v->[1]
               | $v->[0]
               & $nodemask;

            $self->{label}[$1][$2] = $v->[2] if $v->[0] & MARK_LABEL;

            if ($v->[0] & MARK_MOVE) {
               if ($v->[0] & MARK_B) {
                  $self->{last} = COLOUR_BLACK;
                  $self->capture4(MARK_W, $1, $2);
               } else {
                  $self->{last} = COLOUR_WHITE;
                  $self->capture4(MARK_B, $1, $2);
               }
            }
         } elsif ($k eq "timer") {
            $self->{timer}[0] = $v->[0] if defined $v->[0];
            $self->{timer}[1] = $v->[1] if defined $v->[1];
         } elsif ($k eq "pass") {
            $self->{last} = !$self->{last};
         }
      }

      $move++;
   }
}

1;

