package challenge; # challenge widget

use KGS::Constants;

use base gtk::widget;

sub new {
   my $class = shift;
   my $self = $class->SUPER::new(@_);

   $self->{widget} = new Gtk2::Frame "Challenge";
   $self->{widget}->add (my $vbox = new Gtk2::VBox);
   $vbox->add (my $frame = new Gtk2::Frame "Notes");
   $frame->add ($self->{entry} = new Gtk2::Entry);

   $vbox->add (my $hbox = new Gtk2::HBox);

   $hbox->add ($self->{userlist} = new userlist);

   $vbox->add (my $hbox = new Gtk2::HButtonBox);

   $hbox->add (my $button = new Gtk2::Button "OK");
   $hbox->add (my $button = new Gtk2::Button "Decline");
   $hbox->add (my $button = new Gtk2::Button "Cancel");

   $self;
}

sub destroy {
   my ($self) = @_;
   $self->SUPER::destroy;
}

1;


