package KGS::Listener::Channel;

use base KGS::Listener;

sub add_users {
   my ($self, $users) = @_;

   my @added;
   my @updated;
   my $user;
   for (@$users) {
      if ($user = $self->{users}{$_->{name}}) {
         push @updated, $user;
      } else {
         $user = $self->{users}{$_->{name}} = bless {}, ref $_;
         push @added, $user;
      }
      while (my ($k, $v) = each %$_) { $user->{$k} = $v };
      $self->event_join if !$self->{joined} && $_->{name} eq $self->{conn}{name};
   }
   $self->event_update_users (\@added, \@updated, []);
}

sub del_users {
   my ($self, $users) = @_;

   my @deleted;

   for (@$users) {
      $self->event_part if $_->{name} eq $self->{conn}{name};
      push @deleted, delete $self->{users}{$_->{name}};
   }
   $self->event_update_users ([], [], \@deleted) if $self->{joined};
}

sub join {
   my ($self, $type) = @_;
   return if $self->{joined};

   delete $self->{users};
   $self->send($type => channel => $self->{channel}, user => { name => $self->{conn}->{name} });
}

sub part {
   my ($self, $type) = @_;
   return unless $self->{joined};

   $self->send($type => channel => $self->{channel}, name => $self->{conn}->{name});
}

=item $channel->event_join

=cut

sub event_join {
   my ($self) = @_;
   $self->{joined} = 1;
}

=item $channel->event_part

=cut

sub event_part {
   my ($self) = @_;
   $self->{joined} = 0;
   $self->event_update_users ([], [], [values %{(delete $self->{users}) || {}}]);
}

=item $channel->event_update_users ($add, $update, $remove)

=cut

sub event_update_users {}

1;



