use utf8;

package superchat;

# waaay cool widget. well... maybe at one point in the future

use Gtk2;

use Glib::Object::Subclass
   Gtk2::VBox,
   signals => {
      command => {
         flags       => [qw/run-first/],
         return_type => undef, # void return
         param_types => [Glib::Scalar, Glib::Scalar],
      },
   };

sub INIT_INSTANCE {
   my $self = shift;

   my $tagtable = new Gtk2::TextTagTable;

   {
      my @tags = (
         [default     => { foreground => "black" }],
         [node        => { foreground => "#0000b0", event => 1 }],
         [move        => { foreground => "#0000b0", event => 1 }],
         [user        => { foreground => "#0000b0", event => 1 }],
         [coord       => { foreground => "#0000b0", event => 1 }],
         [error       => { foreground => "#ff0000", event => 1 }],
         [header      => { weight => 800, pixels_above_lines => 6 }],
         [challenge   => { weight => 800, pixels_above_lines => 6, background => "#ffffb0" }],
         [description => { weight => 800, foreground => "blue" }],
         [infoblock   => { weight => 700, foreground => "blue" }],
      );

      for (@tags) {
         my ($k, $v) = @$_;
         my $tag = new Gtk2::TextTag $k;
         if (delete $v->{event}) {
            ###
         }
         $tag->set (%$v);
         $tagtable->add ($tag);
      }
   }

   $self->{tagtable} = $tagtable;

   $self->signal_connect (destroy => sub {
      remove Glib::Source delete $self->{idle} if $self->{idle};
      %{$_[0]} = ();
   });

   $self->{buffer} = new Gtk2::TextBuffer $self->{tagtable};

   $self->{widget} = new Gtk2::ScrolledWindow;
   $self->{widget}->set_policy("never", "always");
   $self->pack_start ($self->{widget}, 1, 1, 0);

   $self->{widget}->add ($self->{view} = new_with_buffer Gtk2::TextView $self->{buffer});
   $self->{view}->set_wrap_mode ("word");
   $self->{view}->set_cursor_visible (0);

   $self->{view}->set_editable (0);

   $self->{view}->signal_connect (motion_notify_event => sub {
      my ($widget, $event) = @_;

      my $window = $widget->get_window ("text");
      if ($event->window == $window) {
         my ($win, $x, $y, $mask) = $window->get_pointer;
          #     warn "TAG EVENT @_ ($window, $win, $x, $y, $mask)\n";
          #gtk_text_view_window_to_buffer_coords (text_view,
          #                                       GTK_TEXT_WINDOW_TEXT,
          #                                       text_view->drag_start_x,
          #                                       text_view->drag_start_y,
          #                                       &buffer_x,
          #                                       &buffer_y);
#
#          gtk_text_layout_get_iter_at_pixel (text_view->layout,
#                                             &iter,
#                                             buffer_x, buffer_y);
#
#          gtk_text_view_start_selection_dnd (text_view, &iter, event);
#          return TRUE;
      }
      0;
   });

   $self->pack_start (($self->{entry} = new Gtk2::Entry), 0, 1, 0);

   $self->{entry}->signal_connect (activate => sub {
      my ($entry) = @_;
      my $text = $entry->get_text;
      $entry->set_text("");

      my ($cmd, $arg);

      if ($text =~ /^\/(\S+)\s*(.*)$/) {
         ($cmd, $arg) = ($1, $2);
      } else {
         ($cmd, $arg) = ("say", $text);
      }

      $self->signal_emit (command => $cmd, $arg);
   });

   $self->{end} = $self->{buffer}->create_mark (undef, $self->{buffer}->get_end_iter, 0);

   $self->set_end;
}

sub do_command {
   my ($self, $cmd, $arg, %arg) = @_;
}

sub set_end {
   my ($self) = @_;

   # this is probably also a hack...
   $self->{idle} ||= add Glib::Idle sub {
      $self->{view}->scroll_to_iter ($self->{buffer}->get_end_iter, 0, 0, 0, 0)
         if $self->{view};
      delete $self->{idle};
   };
}

sub at_end {
   my ($self) = @_;

   # this is, maybe, a bad hack :/
   my $adj = $self->{widget}->get_vadjustment;
   $adj->value + $adj->page_size >= $adj->upper - 0.5;
}

sub append_text {
   my ($self, $text) = @_;

   $self->_append_text ($self->{end}, $text);
}

sub _append_text {
   my ($self, $mark, $text) = @_;

   my $at_end = $self->at_end;

   $text = "<default>$text</default>";

   my @tag;
   # pseudo-simplistic-xml-parser
   for (;;) {
      $text =~ /\G<([^>]+)>/gc or last;
      my $tag = $1;
      if ($tag =~ s/^\///) {
         pop @tag;
      } else {
         push @tag, $tag;
      }

      $text =~ /\G([^<]*)/gc or last;
      $self->{buffer}->insert_with_tags_by_name ($self->{buffer}->get_iter_at_mark ($mark), util::xmlto $1, @tag)
         if length $1;
   }

   $self->set_end if $at_end;
}

sub set_text {
   my ($self, $text) = @_;

   my $at_end = $self->at_end;
           
   $self->{buffer}->set_text ("");
   $self->append_text ($text);

   $self->set_end if $at_end;
}

sub new_eventtag {
   my ($self, $cb) = @_;

   my $tag = new Gtk2::TextTag;
   $tag->signal_connect (event => $cb);
   $self->{tagtable}->add ($tag);

   $tag
}

# create a new "subbuffer"
sub new_inlay {
   my ($self) = @_;

   my $end = $self->{buffer}->get_end_iter;

   my $self = bless {
      buffer  => $self->{buffer},
      parent  => $self,
   }, superchat::inlay;

   $self->{l} = $self->{buffer}->create_mark (undef, $end, 1);
   $self->{buffer}->insert ($end, "\x{200d}");
   $self->{r} = $self->{buffer}->create_mark (undef, $self->{buffer}->get_iter_at_mark ($self->{l}), 0);

   Scalar::Util::weaken $self->{buffer};
   Scalar::Util::weaken $self->{parent};
   $self;
}

sub new_switchable_inlay {
   my ($self, $header, $cb, $visible) = @_;

   my $inlay;

   my $tag = $self->new_eventtag (sub {
      my ($tag, $view, $event, $iter) = @_;

      if ($event->type eq "button-press") {
         $inlay->set_visible (!$inlay->{visible});
      }

      1;
   });

   $tag->set (background => "#e0e0ff");

   $inlay = $self->new_inlay;

   $inlay->{visible} = 0;
   $inlay->{header}  = $header;
   $inlay->{tag}     = $tag;
   $inlay->{cb}      = $cb;

   Scalar::Util::weaken $inlay->{tag};

   $inlay->set_visible ($visible);

   $inlay;
}

package superchat::inlay;

sub liter { $_[0]{buffer}->get_iter_at_mark ($_[0]{l}) }
sub riter { $_[0]{buffer}->get_iter_at_mark ($_[0]{r}) }

sub clear {
   my ($self) = @_;
   $self->{buffer}->delete ($self->liter, $self->riter);
}

sub append_text {
   my ($self, $text) = @_;

   $self->{parent}->_append_text ($self->{r}, $text);
}

sub visible { $_[0]{visible} }
sub set_visible {
   my ($self, $visible) = @_;

   return if $self->{visible} == $visible;
   $self->{visible} = $visible;

   $self->refresh;
}

sub refresh {
   my ($self) = @_;

   $self->clear;

   my $arrow = $self->{visible} ? "⊟" : "⊞";

   $self->{buffer}->insert ($self->riter, "\n");
   $self->{buffer}->insert_with_tags ($self->riter, util::xmlto "$arrow $self->{header}", $self->{tag});

   return unless $self->{visible};

   $self->{cb}->($self);
}

sub DESTROY {
   my ($self) = @_;

   $self->{parent}{tagtable}->remove (delete $self->{tag}) if $self->{tag};
}

1;

