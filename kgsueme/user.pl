package user;

use List::Util;

use base KGS::Listener::User;
use base gtk::widget;

sub new {
   my $self = shift;
   $self = $self->SUPER::new(@_);

   $self->listen($self->{conn});

   $self->send (notify_add => name => $self->{name})
      unless (lc $self->{name}) eq (lc $self->{app}{name});

   $self->{window} = new Gtk2::Window 'toplevel';
   $self->event_name;
   gtk::state $self->{window}, "user::window", undef, window_size => [400, 300];

   $self->{window}->signal_connect(delete_event => sub { $self->destroy; 1 });

   my $notebook = new Gtk2::Notebook;

   $notebook->signal_connect (switch_page => sub {
      my ($notebook, undef, $page) = @_;

      $self->userinfo    if $page == 1;
      $self->game_record if $page == 2;
      $self->usergraph   if $page == 3;
   });

   $self->{window}->add ($notebook);

   $self->{chat} = new chat;
   $self->{chat}->signal_connect(command => sub {
      my ($chat, $cmd, $arg) = @_;
      $self->{app}->do_command ($chat, $cmd, $arg, user => $self);
   });

   $notebook->append_page ($self->{chat}, (new_with_mnemonic Gtk2::Label "_Chat"));


   $self->{page_userinfo} = new Gtk2::Table 3, 5, 0;
   $notebook->append_page ($self->{page_userinfo}, (new_with_mnemonic Gtk2::Label "_Info"));


   $self->{page_record} = new Gtk2::VBox;
   $notebook->append_page ($self->{page_record}, (new_with_mnemonic Gtk2::Label "_Record"));


   $self->{page_graph} = new Gtk2::Curve;
   $notebook->append_page ($self->{page_graph}, (new_with_mnemonic Gtk2::Label "_Graph"));


   $self;
}

sub join {
   my ($self) = @_;

   $self->{window}->show_all;
}

sub event_name {
   my ($self) = @_;

   $self->{window}->set_title("KGS User $self->{name}");
}

sub event_userinfo {
   my ($self) = @_;

   my $ui = $self->{page_userinfo};

   $ui->attach_defaults ((new Gtk2::Label "Name"), 0, 1, 0, 1);
   $ui->attach_defaults ((new Gtk2::Label "Email"), 0, 1, 1, 2);
   $ui->attach_defaults ((new Gtk2::Label "Registered"), 0, 1, 2, 3);
   $ui->attach_defaults ((new Gtk2::Label "Last Login"), 0, 1, 3, 4);

   $ui->attach_defaults ((new Gtk2::Label $self->{userinfo}{realname}), 1, 2, 0, 1);
   $ui->attach_defaults ((new Gtk2::Label $self->{userinfo}{email}), 1, 2, 1, 2);
   $ui->attach_defaults ((new Gtk2::Label $self->{userinfo}{regdate}), 1, 2, 2, 3);
   $ui->attach_defaults ((new Gtk2::Label $self->{userinfo}{lastlogin}), 1, 2, 3, 4);

   if ($self->{userinfo}{user}->has_pic) {
      $self->{app}->userpic ($self->{name}, sub {
         if ($_[0]) {
            $ui->attach_defaults ((gtk::image_from_data $_[0]), 2, 3, 0, 4);
            $ui->show_all;
         }
      });
   }

   $ui->attach_defaults ((new Gtk2::Label $self->{userinfo}{info}), 0, 2, 4, 5);

   $ui->show_all;
}

sub event_game_record {
   my ($self) = @_;
}

sub event_usergraph {
   my ($self) = @_;

   my $graph = $self->{usergraph};

   my $curve = $self->{page_graph};

   if (@$graph) {
      $curve->set_range (0, (scalar @graph) - 1, (List::Util::min @$graph) - 1, (List::Util::max @$graph) + 1);
      $curve->set_vector (@$graph);
   }
}

sub event_msg {
   my ($self, $name, $message) = @_;

   $self->{chat}->append_text ("\n<user>$name</user>: $message");
}

sub destroy {
   my ($self) = @_;

   $self->send (notify_del => name => $self->{name})
      unless (lc $self->{name}) eq (lc $self->{app}{name});

   $self->SUPER::destroy;
}

1;

