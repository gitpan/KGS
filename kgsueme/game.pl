use utf8;

package game::goclock;

# Lo and Behold! I admit it! The rounding stuff etc.. in goclock
# is completely borked.

use Time::HiRes ();

use KGS::Constants;

use base gtk::widget;

sub new {
   my $class = shift;
   my $self = $class->SUPER::new(@_);

   $self->{widget} = new Gtk2::Label;

   $self->{set}    = sub { };
   $self->{format} = sub { "ERROR" };

   $self;
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
   $self->{widget}->set_text ($self->{format}->(int ($timer + 0.4)));

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

sub destroy {
   my ($self) = @_;
   $self->stop;
   $self->SUPER::destroy;
}

package game::userpanel;

use base gtk::widget;

sub new {
   my $class = shift;
   my $self = $class->SUPER::new(@_);

   $self->{widget} = new Gtk2::HBox;

   $self->{widget}->add (my $vbox = new Gtk2::VBox);

   $vbox->add ($self->{name} = new Gtk2::Label $self->{name});
   $vbox->add ($self->{info} = new Gtk2::Label "");
   $vbox->add (($self->{clock} = new game::goclock)->widget);

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

use KGS::Constants;
use KGS::Game::Board;

use Gtk2::GoBoard;

use base KGS::Listener::Game;
use base KGS::Game;

use base gtk::widget;

use POSIX qw(ceil);

sub new {
   my $self = shift;
   $self = $self->SUPER::new(@_);

   $self->listen($self->{conn});

   $self->{window} = new Gtk2::Window 'toplevel';
   gtk::state $self->{window}, "game::window", undef, window_size => [600, 500];

   $self->{window}->signal_connect(delete_event => sub {
      $self->part;
      $self->destroy;
      1;
   });

   $self->{window}->add($self->{hpane} = new Gtk2::HPaned);
   gtk::state $self->{hpane}, "game::hpane", undef, position => 500;

   # LEFT PANE

   $self->{hpane}->pack1(($self->{left} = new Gtk2::VBox), 1, 0);
   
   $self->{boardbox} = new Gtk2::VBox;

   $self->{hpane}->pack1((my $vbox = new Gtk2::VBox), 1, 1);

   # challenge

   $self->{challenge} = new challenge channel => $self->{channel};
   
   # board box (aspect/canvas)
   
   $self->{boardbox}->pack_start((my $frame = new Gtk2::Frame), 0, 1, 0);

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

   $self->{boardbox}->add ($self->{board} = new Gtk2::GoBoard size => $self->{size});

   # RIGHT PANE

   $self->{hpane}->pack2(($self->{vpane} = new Gtk2::VPaned), 1, 1);
   $self->{hpane}->set(position_set => 1);
   gtk::state $self->{vpane}, "game::vpane", $self->{name}, position => 80;

   $self->{vpane}->add(my $sw = new Gtk2::ScrolledWindow);
   $sw->set_policy("automatic", "always");

   $sw->add(($self->{userlist} = new userlist)->widget);

   $self->{vpane}->add(my $vbox = new Gtk2::VBox);

   $vbox->pack_start((my $hbox = new Gtk2::HBox 1), 0, 1, 0);
   $hbox->add (($self->{userpanel}[COLOUR_WHITE] = new game::userpanel colour => COLOUR_WHITE)->widget);
   $hbox->add (($self->{userpanel}[COLOUR_BLACK] = new game::userpanel colour => COLOUR_BLACK)->widget);
   
   $vbox->pack_start(($self->{chat} = new chat), 1, 1, 0);

   $self->{chat}->signal_connect(command => sub {
      my ($chat, $cmd, $arg) = @_;
      if ($cmd eq "rsave") {
         Storable::nstore { tree => $self->{tree}, curnode => $self->{curnode}, move => $self->{move} }, $arg;#d#
      } else {
         $self->{app}->do_command ($chat, $cmd, $arg, userlist => $self->{userlist}, game => $self);
      }
   });

   $self->event_update_game;
   $self;
}

sub event_update_users {
   my ($self, $add, $update, $remove) = @_;

   return unless $self->{userlist};

   $self->{userlist}->update ($add, $update, $remove);

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

   $self->{window}->show_all;
}

sub part {
   my ($self) = @_;

   $self->SUPER::part;
   $self->destroy;
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
   $self->SUPER::event_join;
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

   return unless $self->{window};

   my $title = defined $self->{channel}
                  ? $self->owner->as_string . " " . $self->opponent_string
                  : "Game Window";
   $self->{window}->set_title("KGS Game $title");
   $self->{title}->set_text ($title);

   $self->{user}[COLOUR_BLACK] = $self->{user1};
   $self->{user}[COLOUR_WHITE] = $self->{user2};

   # show board
   
   if ($self->is_inprogress) {
      $self->{left}->remove ($self->{challenge}->widget) if $self->{challenge} && $self->{boardbox}->parent;
      $self->{left}->add ($self->{boardbox}) unless $self->{boardbox}->parent;
   } else {
      $self->{left}->remove ($self->{boardbox}) if $self->{boardbox}->parent;
      $self->{left}->add ($self->{challenge}->widget) unless $self->{challenge}->widget->parent;
   }
   $self->{left}->show_all;

   # view text
   
   eval { #d#
   my @ga;
   $ga[0] = "\nType: " . (util::toxml $gametype{$self->type})
            . " (" . (util::toxml $gameopt{$self->option}) . ")";
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

sub event_update_rules {
   my ($self, $rules) = @_;

   $self->{userpanel}[$_]->configure ($self->{app}, $self->{user}[$_], $rules)
      for COLOUR_BLACK, COLOUR_WHITE;

   sound::play 3, "gamestart";

   my $text = "\n<header>Game Rules</header>";

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
   
   $self->{chat}->append_text ("<infoblock>$text</infoblock>");
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

sub event_challenge {
   my ($self, $challenge) = @_;

   use KGS::Listener::Debug;
   $self->{chat}->append_text ("\n".KGS::Listener::Debug::dumpval($challenge));
}

sub destroy {
   my ($self) = @_;

   delete $self->{app}{gamelist}{game}{$self->{channel}};
   $self->{userpanel}[$_] && (delete $self->{userpanel}[$_])->destroy
      for COLOUR_BLACK, COLOUR_WHITE;
   $self->SUPER::destroy;
}

1;

