package KGS::Listener::Room;

use base KGS::Listener::Channel;

sub listen {
   my $self = shift;
   $self->SUPER::listen(@_,
                        qw(join_room: part_room: upd_games: desc_room: msg_room:
                           upd_game del_game));
}

sub join {
   my ($self) = @_;
   $self->{games} = {};
   $self->SUPER::join("join_room");
}

sub part {
   my ($self) = @_;
   $self->SUPER::part("part_room");
}

sub say {
   my ($self, $msg) = @_;
   $self->send(msg_room => channel => $self->{channel}, name => $self->{conn}{name}, message => $msg);
}

sub req_roominfo {
   my ($self) = @_;

   $self->send(req_desc => channel => $self->{channel});
}

sub req_games {
   my ($self) = @_;
   $self->send(req_games => channel => $self->{channel});
}

sub inject_join_room {
   my ($self, $msg) = @_;

   $self->add_users($msg->{users});
}

sub inject_part_room {
   my ($self, $msg) = @_;

   $self->del_users([$msg->{user}]);
}

sub inject_upd_games {
   my ($self, $msg) = @_;

   my @added;
   my @updated;
   my $game;
   for (@{$msg->{games}}) {
      if ($game = $self->{games}{$_->{channel}}) {
         push @updated, $game;
      } else {
         $game = $self->{games}{$_->{channel}} = bless {}, KGS::Game;
         push @added, $game;
      }
      while (my ($k, $v) = each %$_) { $game->{$k} = $v };
   }

   $self->event_update_games (\@added, \@updated, []);
}

sub inject_upd_game {
   my ($self, $msg) = @_;
   return unless exists $self->{games}{$msg->{game}{channel}};

   $self->inject_upd_games ({ games => [ $msg->{game} ] });
}

sub inject_del_game {
   my ($self, $msg) = @_;

   return unless $self->{games}{$msg->{channel}};
   $self->event_update_games ([], [], [delete $self->{games}{$msg->{channel}}]);
}

sub inject_msg_room {
   my ($self, $msg) = @_;

   # nop, should event_*
   #d#
}

sub inject_desc_room {
   my ($self, $msg) = @_;

   $self->{owner}       = $msg->{owner};
   $self->{description} = $msg->{description};

   $self->event_update_roominfo;
}

sub event_join {
   my ($self) = @_;
   $self->SUPER::event_join;
}

sub event_part {
   my ($self) = @_;
   $self->SUPER::event_part;
   $self->event_update_games ([], [], [values %{delete $self->{games}}]);
}

=item $game->event_update_games ($add, $update, $remove)

=cut

sub event_update_games { }

=item $game->event_update_roominfo

=cut

sub event_update_roominfo { }

1;



