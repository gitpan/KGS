package KGS::Listener::Debug;

use base KGS::Listener;

=item dumpval any-perl-ref

Tries to dump the given perl-ref into a nicely-formatted
human-readable-format (currently uses either Data::Dumper or Dumpvalue)
but tries to be I<very> robust about internal errors, i.e. this functions
always tries to output as much usable data as possible without die'ing.

=cut

sub dumpval {
   eval {
      local $SIG{__DIE__};
      my $d;
      require Data::Dumper;
      $d = new Data::Dumper([$_[0]], ["*var"]);
      $d->Terse(1);
      $d->Indent(2);
      $d->Quotekeys(0);
      $d->Useqq(0);
      $d = $d->Dump();
      $d =~ s/([\x00-\x07\x09\x0b\x0c\x0e-\x1f])/sprintf "\\x%02x", ord($1)/ge;
      $d;
   } || "[unable to dump $_[0]: '$@']";
}

sub inject_any {
   my ($self, $msg) = @_;

   if (exists $msg->{channel}) {
      if ($msg->{type} eq "upd_games") {
      } elsif ($msg->{type} eq "join") {
      } elsif ($msg->{type} eq "part") {
      } elsif ($msg->{type} eq "pubmsg") {
      } elsif ($msg->{type} eq "del_game") {
      } elsif ($msg->{type} eq "upd_game") {
      } elsif ($msg->{type} eq "set_tree") {
      } elsif ($msg->{type} eq "join_room") {
      } elsif ($msg->{type} eq "part_room") {
      } elsif ($msg->{type} eq "desc_room") {
      } elsif ($msg->{type} eq "msg_room") {
      #} elsif ($msg->{type} eq "upd_tree") {
      } elsif ($msg->{type} eq "set_node") {
      } elsif ($msg->{type} eq "set_tree") {
      } elsif ($msg->{type} eq "upd_observers") {
      } elsif ($msg->{type} eq "del_observer") {
      } else {
         warn "receivedC $msg->{type} ". dumpval($msg);
      }
   } else {
      if ($msg->{type} eq "login") {
      } elsif ($msg->{type} eq "list_rooms") {
      } elsif ($msg->{type} eq "upd_rooms") {
      } elsif ($msg->{type} eq "chal_defaults") {
      } elsif ($msg->{type} eq "timewarning_default") {
      } else {
         warn "receivedG $msg->{type} ". dumpval($msg);
      }
   }
   #warn "received* $msg->{type} ". dumpval($msg);
}

1;



