package chat;

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

my $tagtable = new Gtk2::TextTagTable;

{
   my %tags = (
      default     => { foreground => "black" },
      node        => { foreground => "#0000b0", event => 1 },
      move        => { foreground => "#0000b0", event => 1 },
      user        => { foreground => "#0000b0", event => 1 },
      coord       => { foreground => "#0000b0", event => 1 },
      error       => { foreground => "#ff0000", event => 1 },
      header      => { weight => 800, pixels_above_lines => 6 },
      description => { weight => 800, foreground => "blue" },
      infoblock   => { weight => 700, foreground => "blue" },
   );

   while (my ($k, $v) = each %tags) {
      my $tag = new Gtk2::TextTag $k;
      if (delete $v->{event}) {
         ###
      }
      $tag->set (%$v);
      $tagtable->add ($tag);
   }
}

sub INIT_INSTANCE {
   my $self = shift;

   $self->signal_connect (destroy => sub {
      remove Glib::Source delete $self->{idle} if $self->{idle};
      %{$_[0]} = ();
   });

   $self->{buffer} = new Gtk2::TextBuffer $tagtable;

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

   $self->{entry}->signal_connect(activate => sub {
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

   my $at_end = $self->at_end;

   my @tag;
   $text = "<default>$text</default>";

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
      $self->{buffer}->insert_with_tags_by_name ($self->{buffer}->get_end_iter, util::xmlto $1, $tag[-1])
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

1;

