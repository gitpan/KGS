package KGS::Listener::Game;

use base KGS::Listener::Channel;
use base KGS::Game::Tree;

sub listen {
   my $self = shift;
   $self->SUPER::listen(@_,
                        qw(upd_observers: del_observer: upd_game: del_game:
                           set_tree: add_tree: upd_tree: resign_game:
                           req_undo: set_teacher: superko: final_result:
                           owner_left: teacher_left: req_result: upd_challenge:));
}

sub join {
   my ($self) = @_;
   return if $self->{joined};

   $self->SUPER::join("join_game");
   $self->init_tree unless $self->{joined};
}

sub part {
   my ($self) = @_;
   $self->SUPER::part("part_game");
}

sub say {
   my ($self, $msg) = @_;
   $self->send(msg_game => channel => $self->{channel}, message => $msg);
}

sub inject_upd_observers {
   my ($self, $msg) = @_;

   $self->add_users($msg->{users});
}

sub inject_del_observer {
   my ($self, $msg) = @_;

   $self->del_users([$msg]);
}

sub inject_upd_game {
   my ($self, $msg) = @_;

   my $game = $msg->{game};

   while (my ($k, $v) = each %$game) { $self->{$k} = $v }
   $self->event_update_game;
}

sub inject_del_game {
   my ($self, $msg) = @_;

   $self->del_users (values %{$self->{users}});
}

sub inject_set_tree {
   my ($self, $msg) = @_;

   $self->update_tree($msg->{tree})
      and $self->event_update_tree;
   $self->{loaded} = 1;
}

sub inject_add_tree {
   my ($self, $msg) = @_;

   $self->update_tree($msg->{tree});
   $self->send(get_tree => channel => $self->{channel}, node => @{$self->{tree}} - 1);
}

sub inject_upd_tree {
   my ($self, $msg) = @_;

   return unless $self->{loaded};

   $self->update_tree($msg->{tree})
      and $self->event_update_tree;
}

sub inject_upd_challenge {
   my ($self, $msg) = @_;

   #$self->{challenge} = $msg->{challenge};#d#
   $self->event_challenge ($msg->{challenge});
}

# sub inject_del_game { # what to do? when?

=item event_update_game

=cut

sub event_update_game { }

sub event_challenge { }

1;



