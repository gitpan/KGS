package KGS::Listener;

=item new

=cut

sub new {
   my $class = shift;
   bless { @_ }, $class;
}

=cut

=item $listener->listen($conn, [msgtype...])

Registers the object to receive callback messages of the named type(s). A
msgtype of C<any> means all msgtypes.

=item $listener->unlisten

Unregisters the object again.

=cut

sub listen {
   my ($self, $conn, @types) = @_;

   $_ =~ s/:$/:$self->{channel}/ for @types;

   if ($conn) {
      $self->unlisten;
      $self->{conn} = $conn;
      $self->{listen_types} = \@types;
      $conn->register($self, @types);
   }
}

sub unlisten {
   my ($self) = @_;

   (delete $self->{conn})
      ->unregister($self, @{$self->{listen_types}}) if $self->{conn};
}

=item $listener->inject($msg)

The main injector callback.. all (listened for) messages end up in this
method, which will just dispatch a method with name inject_<msgtype>.

=cut

sub inject {
   my ($self, $msg) = @_;

   if (my $cb = $self->can("inject_$msg->{type}")) {
      $cb->($self, $msg);
   } elsif (my $cb = $self->can("inject_any")) {
      $cb->($self, $msg);
   } else {
      warn "no handler found for message $msg->{type} in $self\n";
   }
}

=item $listener->send($type, %args);

Calls the C<send> method of the connection when in listen state. It does
not (yet) supply a default channel id.

=cut

sub send {
   my ($self, $type, @arg) = @_;

   $self->{conn}->send($type, @arg) if $self->{conn};
}

sub DESTROY {
   my ($self) = @_;

   $self->unlisten;
}

1;

