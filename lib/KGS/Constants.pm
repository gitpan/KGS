
# This is an automatically generated file. 
# This is an automatically generated file. 
# This is an automatically generated file. 
# This is an automatically generated file. 
# This is an automatically generated file. 

# See doc/protocol.xml and doc/doc2constants_pm.xsl (and doc/Makefile)

package KGS::Constants;

use base Exporter;

BEGIN {
   @EXPORT = qw(

      
      GAMETYPE_DEMONSTRATION GAMETYPE_TEACHING GAMETYPE_FREE GAMETYPE_RATED GAMETYPE_TYPE4 
      GAMEOPT_NONE GAMEOPT_LECTURE GAMEOPT_PRIVATE GAMEOPT_SIMUL 
      GAMEFLAG_SCORED GAMEFLAG_ADJOURNED GAMEFLAG_UPLOADED 
      ROOMFLAG_ADMIN ROOMFLAG_DEFAULT ROOMFLAG_PRIVATE 
      GAMESTATUS_INPLAY 
      SCORE_TIMEOUT SCORE_RESIGN SCORE_FORFEIT SCORE_JIGO SCORE_NO_RESULT SCORE_ADJOURNED SCORE_UNKNOWN 
      RULESET_JAPANESE RULESET_CHINESE  RULESET_AGA RULESET_NEW_ZEALAND 
      TIMESYS_NONE TIMESYS_ABSOLUTE TIMESYS_BYO_YOMI TIMESYS_CANADIAN 
      COLOUR_BLACK COLOUR_WHITE 
      

      %ruleset %timesys %gametype %gameopt %special_score %room_group
      
      INTERVAL_GAMEUPDATES
   );
}



sub GAMETYPE_DEMONSTRATION () { 0 }
sub GAMETYPE_TEACHING () { 1 }
sub GAMETYPE_FREE () { 2 }
sub GAMETYPE_RATED () { 3 }
sub GAMETYPE_TYPE4 () { 4 }
sub GAMEOPT_NONE () { 0 }
sub GAMEOPT_LECTURE () { 1 }
sub GAMEOPT_PRIVATE () { 2 }
sub GAMEOPT_SIMUL () { 3 }
sub GAMEFLAG_SCORED () { 1 }
sub GAMEFLAG_ADJOURNED () { 2 }
sub GAMEFLAG_UPLOADED () { 4 }
sub ROOMFLAG_ADMIN () { 0x01 }
sub ROOMFLAG_DEFAULT () { 0x04 }
sub ROOMFLAG_PRIVATE () { 0x10 }
sub GAMESTATUS_INPLAY () { 0x80 }
sub SCORE_TIMEOUT () { 16384 / 4 }
sub SCORE_RESIGN () { 16385 / 4 }
sub SCORE_FORFEIT () {     0 / 4 }
sub SCORE_JIGO () { 16386 / 4 }
sub SCORE_NO_RESULT () { 16386 / 4 }
sub SCORE_ADJOURNED () { 16387 / 4 }
sub SCORE_UNKNOWN () { 16389 / 4 }
sub RULESET_JAPANESE () { 0 }
sub RULESET_CHINESE  () { 1 }
sub RULESET_AGA () { 2 }
sub RULESET_NEW_ZEALAND () { 3 }
sub TIMESYS_NONE () { 0 }
sub TIMESYS_ABSOLUTE () { 1 }
sub TIMESYS_BYO_YOMI () { 2 }
sub TIMESYS_CANADIAN () { 3 }
sub COLOUR_BLACK () { 0 }
sub COLOUR_WHITE () { 1 }




sub INTERVAL_GAMEUPDATES   () { 60 } # request game list updates this often (seconds).

# gametype (% 5)

%gametype = (
    &GAMETYPE_DEMONSTRATION => "demonstration",
    &GAMETYPE_TEACHING      => "teaching",
    &GAMETYPE_FREE          => "free",
    &GAMETYPE_RATED         => "rated",
    &GAMETYPE_TYPE4         => "<no idea, pls tell me>",
);

# game option (/ 5)

%gameopt = (
   &GAMEOPT_NONE    => "normal",
   &GAMEOPT_LECTURE => "lecture",
   &GAMEOPT_PRIVATE => "private",
   &GAMEOPT_SIMUL   => "simul",
);

# special score values.
# positive == black won, negative == white one

# use the abs value
%special_score = (
   &SCORE_TIMEOUT   => "time",
   &SCORE_RESIGN    => "resign",
   &SCORE_FORFEIT   => "forfeit",

   &SCORE_JIGO      => "jigo",

   &SCORE_NO_RESULT => "NR",
   &SCORE_ADJOURNED => "(adj)",
   &SCORE_UNKNOWN   => "(unknown)",
);

# rule set

%ruleset = (
   &RULESET_JAPANESE    => "japanese",
   &RULESET_CHINESE     => "chinese",
   &RULESET_AGA         => "AGA",
   &RULESET_NEW_ZEALAND => "new zealand",
);

# time system

%timesys = (
   &TIMESYS_NONE     => "none",
   &TIMESYS_ABSOLUTE => "absolute",
   &TIMESYS_BYO_YOMI => "byo-yomi",
   &TIMESYS_CANADIAN => "canadian",
);

# stone/player etc. colours

%room_group = (
   0 => "Main",
   1 => "New Rooms",
   2 => "Clubs",
   3 => "Lessons",
   4 => "Tournaments",
   5 => "Social",
   6 => "National",
);

# misplaced here...
sub findfile {
   my @files = @_;
   file:
   for (@files) {
      for my $prefix (@INC) {
         if (-f "$prefix/$_") {
            $_ = "$prefix/$_";
            next file;
         }
      }
      die "$_: file not found in \@INC\n";
   }
   wantarray ? @files : $files[0];
}

1;

