use utf8;

package KGS::Protocol;

use Carp;
use Compress::Zlib;
use Time::HiRes;
use Scalar::Util;

use KGS::Messages;

my $KGSHOST = "kgs.kiseido.com";
my $KGSPORT = 2379;
my $SGFHOST = "216.93.172.124";

our $NOW; # the time the last packet was received

our $VERSION = "0.2";

sub MSG_CHANNEL() { 0x4000 }

=item new arg => value,...

=cut

sub new {
   my $class = shift;
   my $self = bless {
      @_,
   }, $class;
   $self;
}

sub encode_msg {
   my ($type, %arg) = @_;

   my $msg = $KGS::Messages::enc_client{$type}
      or die "FATAL: tried to send unknown message type '$type'";

   $msg = $msg->(\%arg);
   #print "MSG $type => ", (join " ", %arg), "\n";#d#
   #print "HEX ", (unpack "H*", $msg), "\n";#d#
   #print "ok (y/n)?"; die unless <> =~ /^y/;#d#dd# let's be paranoid.. "don't crash the server, uh-oh"
   
   pack "va*", 2 + length $msg, $msg;
}

# encode/decode functions
sub decode_msg($) {
   my ($type, $data) = unpack "v a*", $_[0];

   my $msg = $KGS::Messages::dec_server{$type};

   if ($msg) {
      $msg->($data);
   } else {
      {
         type => (sprintf "%04x", $type),
         TRAILING_DATA => (unpack "H*", $data),
      };
   }
}

my $CLIENTVERSION = 4; # 4 == 3 + server zlib compressed
my $SERVERVERSION = 3; # since quite some time now

=item send

Format a message and send it to the server.

=cut

sub send($@) {
   my $self = shift;

   #use PApp::Util; print PApp::Util::dumpval [@_];#d#

   my $msg = $self->{generator}->enc_client (encode_msg @_);

   if ($self->{sock}) {
      syswrite $self->{sock}, $msg
         or croak "msg: $!";
   } else {
      warn "KGS::Protocol::send() called without a socket connection\n";
   }
}

sub init {
   my ($self) = @_;

   $self->{generator} = new KGS::Protocol::Generator;
   $self->{zstream} = inflateInit;
}

=item handshake $fh

Do the initial handshaking with the server on the given socket and make it
the current one. This will initialize the communications stack and set the
socket to be used to sending messages.

"Sockets" should not be anywhere near this module, so this will change.

=cut

sub handshake {
   my ($self, $fh) = @_;

   $self->init;
   $self->{sock} = $fh;
   
   syswrite $fh, chr $CLIENTVERSION
      or croak "initial server handshake send: $!";

   sysread $fh, my $buf, 1
      or croak "initial server handshake recv: $!\n";

   $buf eq chr $SERVERVERSION
      or croak "initial server handshake: server version ".(ord $buf)." unsupported";
}

=item login $clientversion, $name, $pass[, $locale]

Login to the server. C<$clientversion> should be a descriptive string that
uniquely identifies the client and the client version.

=cut

sub login {
   my ($self, $clientver, $name, $pass, $locale) = @_;

   $self->{generator}->set_server_seed ($name);

   $self->{name} = $name;
   $self->send(login =>
      name      => $name,
      password  => $pass,
      locale    => $locale,
      guest     => $pass eq "",
      clientver => $clientver,
   );
}

=item disconnect

Disconnect the socket.

=cut

sub disconnect {
   my $self = shift;

   $self->{sock}->close if $self->{sock};
}

=item feed_data $data

Feed new data from the server into this object. This might or might not
result in messages being dispatched.

=cut

sub feed_data {
   my $self = shift;

   $NOW = Time::HiRes::time;

   my ($data, $status) = $self->{zstream}->inflate($_[0]);
   $status == Z_OK or croak "inflate: status is $status";

   $self->{rbuf} .= $data;

   while (($self->{rlen} || 2) <= length $self->{rbuf}) {
      my $data = substr $self->{rbuf}, 0, $self->{rlen} || 2, "";
      if (delete $self->{rlen}) {
         #open XTYPE, "|xtype"; printf XTYPE "%16x", length($data); print XTYPE $data; close XTYPE;#d#

         $self->_inject(decode_msg $self->{generator}->dec_server ($data));
      } else {
         $self->{rlen} = (unpack "v", $data) - 2;
      }
   }
}

sub register {
   my ($self, $obj, @types) = @_;

   for (@types) {
      $self->{cb}{$_}{$obj} = $obj;
      Scalar::Util::weaken $self->{cb}{$_}{$obj};
   }
}

sub unregister {
   my ($self, $obj, @types) = @_;

   delete $self->{cb}{$_}{$obj} for @types;
}

sub _inject {
   my ($self, $msg) = @_;
   
   $msg->{NOW} = $NOW; # timestamps heissen bei mir "NOW"
   #use PApp::Util; warn PApp::Util::dumpval $msg;#d#

   for my $type ("any", $msg->{type}, "$msg->{type}:$msg->{channel}") {
      for my $obj (values %{$self->{cb}{$type} || {}}) {
         $obj->inject($msg) if $obj;
      }
   }
}

=item alloc_channel

Create and return a new channel id, used e.g. for game creation. We start
at one, but cgoban2 seems to start at zero.

=cut

sub alloc_channel {
   my ($self) = @_;

   ++$self->{channel_id};
}

package KGS::User;

sub is_guest	{ $_[0]{flags} & 0x00001 }
sub is_admin	{ $_[0]{flags} & 0x00002 }
#                                0x00004   # never seen
sub is_active	{ $_[0]{flags} & 0x00008 } # logged in(?)
sub is_gone	{ $_[0]{flags} & 0x00010 }
sub is_idle	{ $_[0]{flags} & 0x00020 }
#                                0x00040 # no idea, seen on many users
sub is_playing	{ $_[0]{flags} & 0x00080 }
sub is_reliable	{ $_[0]{flags} & 0x00100 } # reliable ranking?
sub is_ranked	{ $_[0]{flags} & 0x00200 }
#                                0x00400 # no idea
sub is_ranked2	{ $_[0]{flags} & 0x00800 } # very reliably ranked? *g*
sub has_pic	{ $_[0]{flags} & 0x01000 }
sub email_priv	{ $_[0]{flags} & 0x02000 }

sub is_bot_1	{ $_[0]{flags} & 0x10000 } # set on bots
sub is_bot_2	{ $_[0]{flags} & 0x20000 } # set on bots

sub usertype    { ($_[0]{flags} >> 16) & 3 }
# 0 == normal
# 1 == robot (gtp-client)
# 2 == teacher
# 3 == ranked robot

sub is_valid    { length $_[0]{name} }

sub rank {
   $_[0]{flags} >> 24;
}

sub _rank {
   $_[0] <= 0
      ? ""
      : $_[0] <= 30
         ? (31-$_[0]) . "k"
         : $_[0] <= 39
              ? ($_[0] - 30) . "d"
              : ($_[0] - 39) . "p";
}

sub rank_string {
   $_[0]->is_ranked
      ? _rank($_[0]->rank) . ($_[0]->is_reliable ? "" : "?")
      : "-";
}

sub flags_string {
   my $r;

   $r .= "G" if &is_guest;
   $r .= "!" if &is_admin;
   $r .= "+" if &is_active;
   $r .= "-" if &is_gone;
   $r .= "i" if &is_idle;
   $r .= "P" if &is_playing;
   $r .= ":" if &is_ranked2;

   $r .= " (GTP)" if &usertype == 1;
   $r .= " (TEACHER)" if &usertype == 2;
   $r .= " (ROBOT)" if &usertype == 3;

   $r .= sprintf "%04x", $_[0]{flags} & 0xfcc400
      if $_[0]{flags} & 0xfcc400;

   $r;
}

sub as_string {
   sprintf "%s [%s]", $_[0]{name}, $_[0]->rank_string;
}

package KGS::Game;

use KGS::Constants;

sub is_saved      { $_[0]{saved} } # hmm... not a flag...
sub is_scored     { $_[0]{flags} & 0x1 }
sub is_adjourned  { $_[0]{flags} & 0x2 }
# there is more going on, one bit 0x4 and above(?)

sub is_inprogress { $_[0]{handicap} >= 0 } # maybe rename to "complete"? "started"? "has_board"? ;)

sub is_active     {
   &is_inprogress
   && !&is_scored
   && !&is_adjourned
   && &type != GAMETYPE_DEMONSTRATION
   # this is not enough, and probably not the right way to proceed (teacher flag?)
} # clocks should be running?

sub score {
   # due to the peculiar way score values are encoded, we keep special
   # values in the /4 format, while normal scores are represented "as is".
   # this makes it compatible to the /4 format used in trees.
   &is_scored
      ? 8000 > abs $_[0]{moves} ? $_[0]{moves} * (1 / 2) : $_[0]{moves} / 4
      : SCORE_UNKNOWN;
}

sub moves {
   &is_scored
      ? -1
      : $_[0]{moves};
}

sub type {
   ($_[0]{type} & 15) % 5;
}

sub option {
   int +($_[0]{type} & 15) / 5;
}

sub type_char {
   (uc substr ($gametype{&type}, 0, 1))
   . (uc substr ($gameopt{&option}, 0, 1))
}

sub owner {
   length $_[0]{user3}{name}
      ? $_[0]{user3}
      : $_[0]{user2};
}

sub opponent_string {
   $_[0]{user3}{name} ?
      $_[0]{user1}{name} eq $_[0]{user2}{name}
         ? "" : "(".$_[0]{user2}->as_string." - ".$_[0]{user1}->as_string.")"
      : "vs. ".$_[0]{user1}->as_string;
}

sub size {
   $_[0]{size};
}

sub size_string {
   "$_[0]{size}×$_[0]{size}";
}

sub score_string {
   my ($self) = @_;

   my $res;

   if ($self->is_scored) {
      $score = $self->score;
      if ($score < 0) {
         $res = "W+";
         $score *= -1;
      } else  {
         $res = "B+";
      }
      $res .= $special_score{$score} || $score;
   } else {
      $res = "(unfinished)";
   }

   $res;
}

# convinience

sub rules {
   my ($self) = @_;

   my $rules = $self->size_string;

   $rules .= " H$_[0]{handicap}"
          . ($_[0]{komi} < 0 ? $_[0]{komi} : "+$_[0]{komi}")
      if $self->{handicap} >= 0;

   $rules .= " " . $self->score_string
      if $self->is_scored;

   $rules;
}

package KGS::Room;

sub is_admin   { $_[0]{flags} & 0x01 } # maybe only admins (?) hidden (?)
sub is_default { $_[0]{flags} & 0x04 } # auto-join(?)
sub is_private { $_[0]{flags} & 0x10 }

package KGS::Rules;

sub new {
   my $class = shift;
   my $self = bless { 
      gametype => 0,
      ruleset  => RULESET_JAPANESE,
      size     => 19,
      handicap => 0,
      komi     => 6.5,
      timesys  => TIMESYS_BYO_YOMI,
      time     => 20*60,
      interval => 60,
      count    => 10,
   }, $class;
}

package KGS::Challenge;

package KGS::Score;

sub as_string {
   my ($self) = @_;

   my $score = sprintf "%d territory + %d captures", $self->{territory}, $self->{captures};
   $score .= sprintf " + %g komi", $self->{komi} if $self->{komi};
   $score .= sprintf " = %g", $self->{territory} + $self->{captures} + $self->{komi};

   $score;
}

package KGS::Stats;

package KGS::GameRecord;

use KGS::Constants;

use base KGS::Game;

sub revision {
   my ($self) = @_;

   (($self->{user1}{flags} >> 16) & 0x00ff)
   | (($self->{user2}{flags} >>  8) & 0xff00);
}

sub is_inplay {
   $_[0]{flags3} & 0x80;
}

sub _gametype {
   ($_[0]{flags1} >> 4) | (($_[0]{flags2} >> 8) & 0x70);
}

sub gametype {
   &_gametype % 5;
}

sub gameopt {
   int &_gametype / 5;
}

sub size {
   $_[0]{flags3} & 0x3f;
}

sub komi {
   0.5 *
      ($_[0]{flags2} < 0x8000
         ? $_[0]{flags2} & 0x3ff
         : ($_[0]{flags2} & 0x3ff) - 0x400);
}

sub handicap {
   $_[0]{flags3} & 0x3f;
}

sub uri {
   my ($self) = @_;

   return if $self->is_inplay;
   return if $self->{score} == SCORE_ADJOURNED;
   return if $self->gameopt == GAMEOPT_PRIVATE;

   $revision = $self->revision;

   my $p1 = $self->{user1}{name};
   my $p2 = $self->{user2}{name};
   my $p3 = $self->{user3}{name};

   my ($year, $month, $day) = (gmtime $self->{timestamp})[5,4,3];

   my $revisionstring = $revision ? "-" . ($revision+1) : "";
   my $playerstring =
         $p3 && $self->gametype == GAMETYPE_DEMONSTRATION
            ? $p3
            : $p2 eq $p1 
              ? $p2
              : "$p2-$p1";

   sprintf "/games/%d/%d/%d/%s%s.sgf",
           $year + 1900, $month + 1, $day,
           $playerstring, $revisionstring;
}

sub url {
   my $uri = &uri;
   $uri && "http://kgs.kiseido.com$uri";
}

package KGS::Protocol::Generator;

# generate the numbers used for enc/de"crypt"ion

sub new {
   bless { server_state => 0, client_state => 0, server_seed => " " }, shift;
}

sub set_server_seed {
   my ($self, $seed) = @_;

   $self->{server_seed} = $seed;
}

sub enc_client {
   my ($self, $msg) = @_;

   use integer;

   $msg ^= pack "C", $self->{client_state} >> 24;

   $self->{client_state} = $self->{client_state} * 0x4C2AF9B + 0xFFFFFFFB + length $msg;

   #printf "XXX %lx ($self->{client_state})\n", $self->{client_state};
   #printf "XXY %x (%x)\n", $len, 2 + length $msg;

   $msg;
}

*dec_client = \&enc_client;

sub dec_server {
   my ($self, $msg) = @_;

   use integer;

   my $type = unpack "v", $msg;

   #printf "<LEN(%d) type %04x server_state %lx\n", length $msg, $type, $self->{server_state};#d#

   if (42 < length $msg) {
      $type = ($type + $self->{server_state}) & 0xffff;
      (substr $msg, 0, 2) = pack "v", $type;
   }

   $self->{server_state} = $self->{server_state} * ($type - 0x6cdd)
                  + ord substr $self->{server_seed}, $type % length $self->{server_seed};

   #printf ">LEN(%d) type %04x server_state %lx\n", length $msg, (unpack "v", $msg), $self->{server_state};#d#

   $msg;
}

sub enc_server {
   my ($self, $msg) = @_;

   Carp::croak "NYI";
}

1;



