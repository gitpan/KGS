package gtk;

use Carp;
use File::Temp;
use Gtk2;

# I have not yet found a way to simply default style properties
Gtk2::Rc->parse_string(<<EOF);

   style "base" {
      GtkTreeView::vertical_separator = 0
   }
   widget_class "*" style "base"

EOF

our $text_renderer = new Gtk2::CellRendererText;
our $int_renderer  = new Gtk2::CellRendererText;
$int_renderer->set (xalign => 1);

our $state = $util::state->{gtk} ||= {};

# shows the properties of a glib object
sub info {
   my ($idx, $obj) = @_;
   return if $seen{$idx}++;
   print "\n$idx\n";
   for ($obj->list_properties) {
      printf "%-16s %-24s %-24s %s\n", $_->{name}, $_->{type}, (join ":", @{$_->{flags}}), $_->{descr};
   }
}

my %get = (
   window_size     => sub { [ ($_[0]->allocation->values)[2,3] ] },
   #window_pos     => sub { die KGS::Listener::Debug::dumpval [ $_[0]->get_root_origin ] },
   column_size     => sub { $_[0]->get("width") || $_[0]->get("fixed_width") },
   modelsortorder  => sub { [ $_[0]->get_sort_column_id ] },
);

my %set = (
   window_size     => sub { $_[0]->set_default_size (@{$_[1]}) },
   #window_pos     => sub { $_[0]->set_uposition (@{$_[1]}) if @{$_[1]} },
   column_size     => sub { $_[0]->set (fixed_width => $_[1]) },
   modelsortorder  => sub { $_[0]->set_sort_column_id (@{$_[1]}) },
);

my %widget;

sub state {
   my ($widget, $class, $instance, %attr) = @_;

   while (my ($k, $v) = each %attr) {
      my ($set, $get) = $k =~ /=/ ? split /=/, $k : ($k, $k);

      $v = $state->{$class}{"*"}{$get}
         if exists $state->{$class}{"*"} && exists $state->{$class}{"*"}{$get};

      $v = $state->{$class}{$instance}{$get}
         if defined $instance
         && exists $state->{$class}{$instance} && exists $state->{$class}{$instance}{$get};

      $set{$get} ? $set{$get}->($widget, $v) : $widget->set($set => $v);

      #my $vx = KGS::Listener::Debug::dumpval $v; $vx =~ s/\s+/ /g; warn "set $class ($instance) $set => $vx\n";#d#
   }

   #$widget->signal_connect(destroy => sub { delete $widget{$widget}; 0 });

   $widget{$widget} = [$widget, $class, $instance, \%attr];
   Scalar::Util::weaken $widget{$widget}[0];
}

sub save_state {
   for (grep $_, values %widget) {
      my ($widget, $class, $instance, $attr) = @$_;

      next unless $widget; # no destroy => widget may be undef

      $widget->realize if $widget->can("realize");

      while (my ($k, $v) = each %$attr) {
         my ($set, $get) = $k =~ /=/ ? split /=/, $k : ($k, $k);
         $v = $get{$get} ? $get{$get}->($widget) : $widget->get($get);

         $state->{$class}{"*"}{$get}       = $v;
         $state->{$class}{$instance}{$get} = $v if defined $instance;

         #my $vx = KGS::Listener::Debug::dumpval $v; $vx =~ s/\s+/ /g; warn "get $class ($instance) $get => $vx\n";#d#
      }
   }
}

# string => Gtk2::Image
sub image_from_data {
   my ($data) = @_;
   my $img;
   
   if (defined $data) {
      # need to write to file first :/
      my ($fh, $filename) = File::Temp::tempfile ();
      syswrite $fh, $data;
      close $fh;
      $img = new_from_file Gtk2::Image $filename;
      unlink $filename;
   } else {
      $img = new_from_file Gtk2::Image KGS::Constants::findfile "KGS/kgsueme/images/default_userpic.png";
   }

   $img;
}

package gtk::widget;

# hacked gtk pseudo-widget

sub new {
   my $class = shift;
   bless { @_ }, $class;
}

sub widget { $_[0]{widget} }

sub AUTOLOAD {
   $AUTOLOAD =~ /::([^:]+)$/ or Carp::confess "$AUTOLOAD: no such method (illegal name)";
   ref $_[0]{widget} or Carp::confess "AUTOLOAD: non-method call $AUTOLOAD(@_)\n";
   my $method = $_[0]{widget}->can($1)
      or Carp::confess "$AUTOLOAD: no such method";
   # do NOT cache.. we are fats enough this way
   unshift @_, shift->{widget};
   &$method;
}

sub destroy {
   my ($self) = @_;
   warn "destroy($self)";#d#

   delete $self->{app};

   for (keys %$self) {
      warn "$self->{$_} destroy" if UNIVERSAL::can ($self->{$_}, "destroy");
      (delete $self->{$_})->destroy
         if UNIVERSAL::can ($self->{$_}, "destroy");
#         if (UNIVERSAL::isa ($self->{$_}, Glib::Object)
#             && UNIVERSAL::isa ($self->{$_}, gtk::widget))
#            && $self->{$_}->can("destroy");
   }
}

sub DESTROY {
   my ($self) = @_;
   warn "DESTROY($self)";#d#
}

1;

