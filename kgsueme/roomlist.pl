package roomlist;

use KGS::Constants;

use base KGS::Listener::Roomlist;
use base gtk::widget;

sub new {
   my $self = shift;
   $self = $self->SUPER::new(@_);

   $self->listen($self->{conn});

   $self->{widget} = new Gtk2::Window 'toplevel';
   $self->{widget}->set_title('KGS Rooms');
   gtk::state $self->{widget}, "roomlist::window", undef, window_size => [450, 200];

   $self->{widget}->signal_connect(delete_event => sub { $self->{widget}->hide; 1 });

   $self->{widget}->add(my $vbox = new Gtk2::VBox);

   $vbox->pack_start((my $sw = new Gtk2::ScrolledWindow), 1, 1, 0);
   $sw->set_policy("automatic", "always");

   $self->{roomlist} = new Gtk2::ListStore Glib::Scalar, Glib::String, Glib::String, Glib::Int, Glib::Int, Glib::Int, Glib::Int;
   gtk::state $self->{roomlist}, "roomlist::model", undef, modelsortorder => [2, 'descending'];

   $sw->add(my $treeview = new Gtk2::TreeView $self->{roomlist});

   $treeview->set_search_column (1);

   my $idx = 1;
   for ("Group", "Room Name", "Us", "Gs", "Fs", "Ch") {
      $renderer = $idx < 3 ? $gtk::text_renderer : $gtk::int_renderer;

      # Gtk2-bug, need to keep these objects around
      my $column = $self->{rlcolumns}[$idx] = Gtk2::TreeViewColumn->new_with_attributes ($_, $renderer, text => $idx);

      $column->set_sort_column_id($idx);
      $column->set(resizable => 1, sizing => 'fixed', clickable => 1);
      gtk::state $column, "roomlist::model::$_", undef,
         column_size => [0, 60, 450, 60, 60, 60, 60]->[$idx];
      $treeview->append_column ($column);
      
      $idx++;
   }

   $treeview->signal_connect(row_activated => sub {
      my ($widget, $path, $column) = @_;
      my $room = $self->{roomlist}->get ($self->{roomlist}->get_iter ($path), 0);
      $self->{app}->open_room (%$room);
   });

   $self;
}

sub show {
   my ($self, $msg) = @_;

   $self->send(list_rooms => group => $_) for 0..5; # fetch all room names (should not!)
   $self->show_all;
}

sub event_update_rooms {
   my ($self) = @_;

   $self->{event_update} ||= add Glib::Timeout 200, sub {
      my $l = $self->{roomlist};

      $l->clear;

      my $row = 0;
      for (values %{$self->{rooms}}) {
         $l->set ($l->append,
                      0 => $_,
                      1 => ($room_group{$_->{group}} || $_->{group}),
                      2 => $_->{name},
                      3 => $_->{users},
                      4 => $_->{games},
                      5 => $_->{flags},
                      6 => $_->{channel});
      }

      delete $self->{event_update};
      0;
   };
}

1;

