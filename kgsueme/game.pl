use utf8;

use Scalar::Util ();

package game::goclock;

# Lo and Behold! I admit it! The rounding stuff etc.. in goclock
# is completely borked.

use Time::HiRes ();

use KGS::Constants;

use Glib::Object::Subclass
   Gtk2::Label;

sub INIT_INSTANCE {
   my $self = shift;

   $self->signal_connect (destroy => sub { $_[0]->stop });

   $self->{set}    = sub { };
   $self->{format} = sub { "???" };
}

sub configure {
   my ($self, $timesys, $main, $interval, $count) = @_;

   if ($timesys == TIMESYS_ABSOLUTE) {
      $self->{set}    = sub { $self->{time} = $_[0] };
      $self->{format} = sub { util::format_time $_[0] };

   } elsif ($timesys == TIMESYS_BYO_YOMI) {
      my $low = $interval * $count;

      $self->{set}    = sub { $self->{time} = $_[0] };

      $self->{format} = sub {
         if ($_[0] > $low) {
            util::format_time $_[0] - $low;
         } else {
            sprintf "%s (%d)",
                    util::format_time int (($_[0] - 1) % $interval + 1),
                    ($_[0] - 1) / $interval;
         }
      };

   } elsif ($timesys == TIMESYS_CANADIAN) {
      $self->{set}    = sub { $self->{time} = $_[0]; $self->{moves} = $_[1] };

      $self->{format} = sub {
         if (!$self->{moves}) {
            util::format_time $_[0] - $low;
         } else {
            my $time = int (($_[0] - 1) % $interval + 1);

            sprintf "%s/%d =%d",
                    util::format_time $time,
                    $self->{moves},
                    $self->{moves} > 1
                       ? $time / $self->{moves}
                       : $interval;
         }
      };

   } else {
      # none, or unknown
      $self->{set}    = sub { };
      $self->{format} = sub { "---" }
   }
}

sub refresh {
   my ($self, $timestamp) = @_;
   my $timer = $self->{time} + $self->{start} - $timestamp;
 
   # we round the timer value slightly... the protocol isn't exact anyways,
   # and this gives smoother timers ;)
   my @format = $self->{format}->(int ($timer + 0.4));
   $self->set_text ($self->{format}->(int ($timer + 0.4)));

   $timer - int $timer;
}

sub set_time {
   my ($self, $time) = @_;

   # we ignore requests to re-set the time of a running clock.
   # this is the easiest way to ensure that commentary etc.
   # doesn't re-set the clock. yes, this is frickle design,
   # but I think the protocol is to blame here, which gives
   # very little time information. (cgoban2 also has had quite
   # a lot of small time update problems...)
   unless ($self->{timeout}) {
      $self->{set}->($time->[0], $time->[1]);
      $self->refresh ($self->{start});
   }
}

sub start {
   my ($self, $when) = @_;

   $self->stop;

   $self->{start} = $when;

   my $timeout; $timeout = sub {
      my $next = $self->refresh (Time::HiRes::time) * 1000;
      $next += 1000 if $next < 0;
      $self->{timeout} = add Glib::Timeout $next, $timeout;
      0;
   };

   $timeout->();
}

sub stop {
   my ($self) = @_;

   remove Glib::Source delete $self->{timeout} if $self->{timeout};
}

package game::userpanel;

use Glib::Object::Subclass
   Gtk2::HBox,
   properties => [
      Glib::ParamSpec->IV ("colour", "colour", "User Colour", 0, 1, 0, [qw(construct-only writable)]),
   ];

sub INIT_INSTANCE {
   my ($self) = @_;

   $self->add (my $vbox = new Gtk2::VBox);

   $vbox->add ($self->{name} = new Gtk2::Label $self->{name});
   $vbox->add ($self->{info} = new Gtk2::Label "");
   $vbox->add ($self->{clock} = new game::goclock); Scalar::Util::weaken $self->{clock};

   $vbox->add ($self->{imagebox} = new Gtk2::VBox);

   $self;
}

sub configure {
   my ($self, $app, $user, $rules) = @_;

   if ($self->{name}->get_text ne $user->as_string) {
      $self->{name}->set_text ($user->as_string);

      $self->{imagebox}->remove ($_) for $self->{imagebox}->get_children;
      $self->{imagebox}->add (gtk::image_from_data undef);
      $self->{imagebox}->show_all;

      if ($user->has_pic) {
         # the big picture...
         $app->userpic ($user->{name}, sub {
            return unless $self->{imagebox};

            if ($_[0]) {
               $self->{imagebox}->remove ($_) for $self->{imagebox}->get_children;
               $self->{imagebox}->add (gtk::image_from_data $_[0]);
               $self->{imagebox}->show_all;
            }
         });
      }
   }
   
   $self->{clock}->configure (@{$rules}{qw(timesys time interval count)});
}

sub set_state {
   my ($self, $captures, $timer, $when) = @_;

   $self->{clock}->stop unless $when;
   $self->{clock}->set_time ($timer);
   $self->{clock}->start ($when) if $when;

   $self->{info}->set_text ("$captures pris.");
}

package game;

use Scalar::Util qw(weaken);

use KGS::Constants;
use KGS::Game::Board;

use Gtk2::GoBoard;

use Glib::Object::Subclass
   Gtk2::Window;

use base KGS::Listener::Game;
use base KGS::Game;

use POSIX qw(ceil);

sub new {
   my ($self, %arg) = @_;
   $self = $self->Glib::Object::new;
   $self->{$_} = delete $arg{$_} for keys %arg;

   $self->listen ($self->{conn});

   gtk::state $self, "game::window", undef, window_size => [600, 500];

   $self->signal_connect (delete_event => sub { $self->part; 1 });
   $self->signal_connect (destroy => sub {
      $self->unlisten;
      delete $self->{app}{game}{$self->{channel}};
      %{$_[0]} = ();
   });#d#

   $self->add (my $hpane = new Gtk2::HPaned);
   gtk::state $hpane, "game::hpane", undef, position => 500;

   # LEFT PANE

   $hpane->pack1 (($self->{left} = new Gtk2::VBox), 1, 0);
   
   $self->{boardbox} = new Gtk2::VBox;

   $hpane->pack1((my $vbox = new Gtk2::VBox), 1, 1);

   # board box (aspect/canvas)
   
   #$self->{boardbox}->pack_start((my $frame = new Gtk2::Frame), 0, 1, 0);

   # RIGHT PANE

   $hpane->pack2 ((my $vbox = new Gtk2::VBox), 1, 1);
   $hpane->set (position_set => 1);

   $vbox->pack_start ((my $frame = new Gtk2::Frame), 0, 1, 0);

   {
      $frame->add (my $vbox = new Gtk2::VBox);
      $vbox->add ($self->{title} = new Gtk2::Label $title);

      $vbox->add (my $hbox = new Gtk2::HBox);

      $hbox->pack_start (($self->{board_label} = new Gtk2::Label), 0, 1, 0);

      $self->{moveadj} = new Gtk2::Adjustment 1, 1, 1, 1, 5, 0;

      $hbox->pack_start ((my $scale = new Gtk2::HScale $self->{moveadj}), 1, 1, 0);
      $scale->set_draw_value (0);
      $scale->set_digits (0);

      $self->{moveadj}->signal_connect (value_changed => sub { $self->update_board });
   }

   $vbox->pack_start ((my $hbox = new Gtk2::HBox 1), 0, 1, 0);

   $hbox->add ($self->{userpanel}[$_] = new game::userpanel colour => $_)
      for COLOUR_WHITE, COLOUR_BLACK;
   
   $vbox->pack_start (($self->{chat} = new superchat), 1, 1, 0);

   $self->{rules_inlay} = $self->{chat}->new_switchable_inlay ("Game Rules", sub { $self->draw_rules (@_) }, 1);
   $self->{users_inlay} = $self->{chat}->new_switchable_inlay ("Users:", sub { $self->draw_users (@_) }, 0);

   $self->{chat}->signal_connect (command => sub {
      my ($chat, $cmd, $arg) = @_;
      if ($cmd eq "rsave") {
         Storable::nstore { tree => $self->{tree}, curnode => $self->{curnode}, move => $self->{move} }, $arg;#d#
      } else {
         $self->{app}->do_command ($chat, $cmd, $arg, userlist => $self->{userlist}, game => $self);
      }
   });

   $self;
}

sub event_update_users {
   my ($self, $add, $update, $remove) = @_;

#   $self->{userlist}->update ($add, $update, $remove);

   $self->{users_inlay}->refresh;

   my %important;
   $important{$self->{user1}{name}}++;
   $important{$self->{user2}{name}}++;
   $important{$self->{user3}{name}}++;

   if (my @users = grep $important{$_->{name}}, @$add) {
      $self->{chat}->append_text ("\n<header>Joins:</header>");
      $self->{chat}->append_text (" <user>" . $_->as_string . "</user>") for @users;
   }
   if (my @users = grep $important{$_->{name}}, @$remove) {
      $self->{chat}->append_text ("\n<header>Parts:</header>");
      $self->{chat}->append_text (" <user>" . $_->as_string . "</user>") for @users;
   }

}

sub join {
   my ($self) = @_;
   return if $self->{joined};

   $self->SUPER::join;
}

sub update_board {
   my ($self) = @_;
   return unless $self->{path};

   my $move = int $self->{moveadj}->get_value;

   my $running = $move == @{$self->{path}};

   $self->{board_label}->set_text ("Move " . ($move - 1));

   $self->{cur_board} = new KGS::Game::Board $self->{size};
   $self->{cur_board}->interpret_path ([@{$self->{path}}[0 .. $move - 1]]);

   for my $colour (COLOUR_WHITE, COLOUR_BLACK) {
      $self->{userpanel}[$colour]->set_state (
         $self->{cur_board}{captures}[$colour],
         $self->{cur_board}{timer}[$colour],
         ($running && $self->{lastmove_colour} == !$colour)
            ? $self->{lastmove_time} : 0
      );
   }

   $self->{board}->set_board ($self->{cur_board});
}

sub event_update_tree {
   my ($self) = @_;

   $self->{path} = $self->get_path;

   if ($self->{moveadj}) {
      my $upper = $self->{moveadj}->upper;
      my $pos = $self->{moveadj}->get_value;
      my $move = scalar @{$self->{path}};

      $self->{moveadj}->upper ($move);
      
      $self->{moveadj}->changed;
      if ($pos == $upper) {
         $self->{moveadj}->value ($move);
         $self->{moveadj}->value_changed;
      }
   }
}

sub event_update_comments {
   my ($self, $node, $comment, $newnode) = @_;
   $self->SUPER::event_update_comments($node, $comment, $newnode);

   my $text;

   $text .= "\n<header>Move <move>$node->{move}</move>, Node <node>$node->{id}</node></header>"
      if $newnode;

   for (split /\n/, $comment) {
      $text .= "\n";
      if (s/^([0-9a-zA-Z]+ \[[0-9dkp\?\-]+\])://) {
         $text .= "<user>" . (util::toxml $1) . "</user>:";
      }
      
      # coords only for 19x19 so far
      $_ = util::toxml $_;
      s{
         (
            \b
            (?:[bw])?
            [, ]{0,2}
            [a-hj-t] # valid for upto 19x19
            \s?
            [1-9]?[0-9]
            \b
         )
      }{
         "<coord>$1</coord>";
      }sgexi;

      $text .= $_;
   }

   $self->{chat}->append_text ($text);
}

sub event_join {
   my ($self) = @_;

   $self->SUPER::event_join (@_);
   $self->event_update_game;
   $self->show_all;
}

sub event_part {
   my ($self) = @_;

   $self->SUPER::event_part;
   $self->destroy;
}

sub event_move {
   my ($self, $pass) = @_;
   sound::play 1, $pass ? "pass" : "move";
}

sub event_update_game {
   my ($self) = @_;
   $self->SUPER::event_update_game;

   return unless $self->{joined};

   my $title = defined $self->{channel}
                  ? $self->owner->as_string . " " . $self->opponent_string
                  : "Game Window";
   $self->set_title("KGS Game $title");
   $self->{title}->set_text ($title);

   $self->{user}[COLOUR_BLACK] = $self->{user1};
   $self->{user}[COLOUR_WHITE] = $self->{user2};

   # show board
   if ($self->is_inprogress) {
      if (!$self->{boardbox}->parent) {
         $self->{boardbox}->add ($self->{board} = new Gtk2::GoBoard size => $self->{size});
         $self->{left}->add ($self->{boardbox});
      }
      if (my $ch = delete $self->{challenge}) {
         (delete $_->{inlay})->clear for values %$ch;
      }
   }

   $self->{left}->show_all;

   # view text
   
   eval { #d#
   my @ga;
   $ga[0] = "\nType: " . util::toxml $self->type_char;
   $ga[1] = "\nFlags:";
   $ga[1] .= " started"   if $self->is_inprogress;
   $ga[1] .= " adjourned" if $self->is_adjourned;
   $ga[1] .= " scored"    if $self->is_scored;
   $ga[1] .= " saved"     if $self->is_saved;

   $ga[2] = "\nOwner: <user>" . (util::toxml $self->{user3}->as_string) . "</user>"
      if $self->{user3}->is_inprogress;

   $ga[3] = "\nPlayers: <user>" . (util::toxml $self->{user2}->as_string) . "</user>"
            . " vs. <user>" . (util::toxml $self->{user1}->as_string) . "</user>"
      if $self->is_inprogress;

   if ($self->is_inprogress) {
      $ga[4] = "\nHandicap: " . $self->{handicap};
      $ga[5] = "\nKomi: " . $self->{komi};
      $ga[6] = "\nSize: " . $self->size_string;
   }

   if ($self->is_scored) {
      $ga[7] = "\nResult: " . $self->score_string;
   }

   $text = "\n<infoblock><header>Game Update</header>";
   for (0..7) {
      if ($self->{gatext}[$_] ne $ga[$_]) {
         $text .= $ga[$_];
      }
   }
   $text .= "</infoblock>";

   $self->{gatext} = \@ga;
   };
   
   $self->{chat}->append_text ($text);
}

sub draw_rules {
   my ($self, $inlay) = @_;

   my $rules = $self->{rules};

   my $text = "";

   $text .= "\nRuleset: " . $ruleset{$rules->{ruleset}};

   $text .= "\nTime: ";

   if ($rules->{timesys} == TIMESYS_NONE) {
      $text .= "UNLIMITED";
   } elsif ($rules->{timesys} == TIMESYS_ABSOLUTE) {
      $text .= util::format_time $rules->{time};
      $text .= " ABS";
   } elsif ($rules->{timesys} == TIMESYS_BYO_YOMI) {
      $text .= util::format_time $rules->{time};
      $text .= sprintf " + %s (%d) BY", util::format_time $rules->{interval}, $rules->{count};
   } elsif ($rules->{timesys} == TIMESYS_CANADIAN) {
      $text .= util::format_time $rules->{time};
      $text .= sprintf " + %s/%d CAN", util::format_time $rules->{interval}, $rules->{count};
   }
   
   $inlay->append_text ("<infoblock>$text</infoblock>");
}

sub event_update_rules {
   my ($self, $rules) = @_;

   $self->{rules} = $rules;

   if ($self->{user}) {
      $self->{userpanel}[$_]->configure ($self->{app}, $self->{user}[$_], $rules)
         for COLOUR_BLACK, COLOUR_WHITE;
   }

   sound::play 3, "gamestart";

   $self->{rules_inlay}->refresh;
}

sub inject_resign_game {
   my ($self, $msg) = @_;

   sound::play 3, "resign";

   $self->{chat}->append_text ("\n<infoblock><header>Resign</header>"
                               . "\n<user>"
                               . (util::toxml $self->{user}[$msg->{player}]->as_string)
                               . "</user> resigned.</infoblock>");
}

sub inject_final_result {
   my ($self, $msg) = @_;

   $self->{chat}->append_text ("<infoblock>\n<header>Game Over</header>"
                               . "\nWhite Score " . (util::toxml $msg->{whitescore}->as_string)
                               . "\nBlack Score " . (util::toxml $msg->{blackscore}->as_string)
                               . "</infoblock>"
                              );
}

sub draw_challenge {
   my ($self, $c) = @_;

   my $inlay     = $c->{inlay};
   my $challenge = $c->{challenge};
   my $rules     = $challenge->{rules};

   my $as_black = $challenge->{user1}{name} eq $self->{conn}{name};
   my $opponent = $as_black ? $challenge->{user2} : $challenge->{user1};

   $inlay->append_text ("\n<challenge>Challenge to <user>" . $opponent->as_string . "</user></challenge>");
   $inlay->append_text ("\nHandicap: $rules->{handicap}");

#bless( (
#                gametype => 3,
#                user1 => bless( {
#                                  flags => 2633,
#                                  name => 'dorkusx'
#                                }, 'KGS::User' ),
#                rules => bless( {
#                                  count => 5,
#                                  time => 900,
#                                  timesys => 2,
#                                  interval => 30,
#                                  komi => '6.5',
#                                  size => 19,
#                                  ruleset => 0,
#                                  handicap => 0
#                                }, 'KGS::Rules' ),
#                user2 => bless( {
#                                  flags => 436220808,
#                                  name => 'Nerdamus'
#                                }, 'KGS::User' )
#              ), 'KGS::Challenge' )
}

sub draw_users {
   my ($self, $inlay) = @_;

   for (sort keys %{$self->{users}}) {
      $inlay->append_text ("  <user>" . $self->{users}{$_}->as_string . "</user>");
   }
}

sub event_challenge {
   my ($self, $challenge) = @_;

   my $as_black = $challenge->{user1}{name} eq $self->{conn}{name};
   my $opponent = $as_black ? $challenge->{user2} : $challenge->{user1};

   my $c = $self->{challenge}{$opponent->{name}} ||= {};

   $c->{inlay} ||= $self->{chat}->new_inlay;
   $c->{challenge} = $challenge;

   $self->draw_challenge ($c);

#   require KGS::Listener::Debug;
#   $self->{chat}->append_text ("\n".KGS::Listener::Debug::dumpval($challenge));
}

1;

