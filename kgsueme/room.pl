package room;

use KGS::Constants;

use base KGS::Listener::Room;
use base gtk::widget;

sub new {
   my $self = shift;
   $self = $self->SUPER::new(@_);

   $self->listen($self->{conn}, qw(msg_room:));

   $self->{window} = new Gtk2::Window 'toplevel';
   $self->{window}->set_title("KGS Room $self->{name}");
   gtk::state $self->{window}, "room::window", $self->{name}, window_size => [600, 400];

   $self->{window}->signal_connect(delete_event => sub { $self->part; 1 });

   $self->{window}->add($self->{hpane} = new Gtk2::HPaned);
   $self->{hpane}->set(position_set => 1);
   gtk::state $self->{hpane}, "room::hpane", $self->{name}, position => 200;

   $self->{hpane}->pack1((my $vbox = new Gtk2::VBox), 1, 1);
   
   $vbox->add($self->{chat} = new chat);

   $self->{chat}->signal_connect(command => sub {
      my ($chat, $cmd, $arg) = @_;
      $self->{app}->do_command ($chat, $cmd, $arg, userlist => $self->{userlist}, room => $self);
   });

   $self->{hpane}->pack2((my $sw = new Gtk2::ScrolledWindow), 0, 1);
   $sw->set_policy("automatic", "always");

   $sw->add(($self->{userlist} = new userlist)->widget);

   $self;
}

sub join {
   my ($self) = @_;
   $self->SUPER::join;

   $self->{window}->show_all;
}

sub part {
   my ($self) = @_;
   $self->SUPER::part;

   $self->destroy; # yeaha
}

sub inject_msg_room {
   my ($self, $msg) = @_;

   # secret typoe ;-)
   $self->{chat}->append_text("\n<header><user>" . (util::toxml $msg->{name})
                              . "</user>: </header>" . (util::toxml $msg->{message}));
}

sub event_update_users {
   my ($self, $add, $update, $remove) = @_;

   $self->{userlist}->update ($add, $update, $remove);
}

sub event_update_games {
   my ($self, $add, $update, $remove) = @_;

   $self->{app}{gamelist}->update ($self, $add, $update, $remove);
}

sub event_join {
   my ($self) = @_;
   $self->SUPER::event_join;

   $::config->{rooms}{$self->{channel}} = { channel => $self->{channel}, name => $self->{name} };

   # mysteriously enough, we have to request game updates manually
   $self->{gameupdate} ||= add Glib::Timeout INTERVAL_GAMEUPDATES * 1000, sub {
      $self->req_games;
      1;
   };
}

sub event_part {
   my ($self) = @_;

   delete $::config->{rooms}{$self->{channel}};
   delete $self->{app}{roomlist}{room}{$self->{channel}};
   (remove Glib::Source delete $self->{gameupdate}) if $self->{gameupdate};
   $self->unlisten;

   $self->SUPER::event_part;
}

sub event_update_roominfo {
   my ($self) = @_;

   $self->{chat}->append_text("\n<user>" . (util::toxml $self->{owner}) . "</user>\n"
                              . "<description>" . (util::toxml $self->{description}) . "</description>\n");
}

sub destroy {
   my ($self) = @_;

   $self->event_part;

   $self->SUPER::destroy;
}

1;

