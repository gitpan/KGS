package userlist;

use base gtk::widget;

sub new {
   my $class = shift;
   my $self = $class->SUPER::new(@_);

   $self->{model} = new Gtk2::ListStore Glib::String, Glib::String, Glib::String, Glib::Int, Glib::String;
   gtk::state $self->{model}, "userlist::model", undef, modelsortorder => [2, 'descending'];

   $self->{widget} = new Gtk2::TreeView $self->{model};

   $self->{widget}->set (rules_hint => 0, search_column => 1);

   my $column = $self->{rlcolumns}[0] =
      Gtk2::TreeViewColumn->new_with_attributes ("Name", $gtk::text_renderer, text => 0);
   $column->set_sort_column_id(1);
   $column->set(sizing => 'grow-only');
   $self->{widget}->append_column ($column);

   my $column = $self->{rlcolumns}[1] =
      Gtk2::TreeViewColumn->new_with_attributes ("Rk", $gtk::text_renderer, text => 2);
   $column->set_sort_column_id(3);
   $column->set(sizing => 'grow-only');
   $self->{widget}->append_column ($column);

   my $column = $self->{rlcolumns}[2] =
      Gtk2::TreeViewColumn->new_with_attributes ("Flags", $gtk::text_renderer, text => 4);
   $column->set(resizable => 1);
   $column->set(sizing => 'grow-only');
   $self->{widget}->append_column ($column);

   $self->{widget}->signal_connect(row_activated => sub {
      my ($widget, $path, $column) = @_;
      my $user = $self->{users}{$self->{model}->get ($self->{model}->get_iter ($path), 0)}
         or return 1;
      warn "selected user $user\n";
      1;
   });

   $self;
}

sub update {
   my ($self, $add, $update, $remove) = @_;

   my $l = $self->{model};

   for (@$remove) {
      $l->remove (delete $_->{iter}) if $_->{iter};
   }

   for (@$add, @$update) {
      $l->set ($_->{iter} ||= $l->append,
                   0, $_->{name},
                   1, lc $_->{name},
                   2, $_->rank_string,
                   3, $_->rank,
                   4, $_->flags_string);
   }
}

1;


