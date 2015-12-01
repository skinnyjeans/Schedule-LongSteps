use strict;
use warnings;
package Schedule::LongSteps;

# ABSTRACT: Manage sets of steps accross days, months, years.

=head1 NAME

Schedule::LongSteps - Manage sets of steps accross days, months, years

=head1 ABSTRACT

This attempts to solve the problem of defining and running a serie of steps, maybe conditional accross an arbitrary long timespan.

An example of such a process would be: "After an order has been started, if more than one hour, send an email reminder every 2 days until the order is finished. Give up after a month"". You get the idea.

A serie of steps like that is usually a pain to implement and this is an attempt to provide a framework so it would make writing and testing such a process as easy as writing and testing an good old Class.

=head1 CONCEPTS

=head2 Process

A process is an unordered collection of named steps, the name of an initial step

=head1 SYNOPSIS

First write a class to represent your long running set of steps

  package My::Application::MyLongProcess;

  use Moose;
  extends qw/Schedule::LongSteps::Process/;

  has 'thing' => ( is => 'ro', required => 1); # Some mandatory context provided by your application at each regular run.

  # The first step should be executed after the process is installed on the target.
  sub build_first_step{
    my ($self) = @_;
    return Schedule::LongSteps::Step->new({ what => 'do_stuff1', when => DateTime->now() });
  }

  sub do_stuff1{
     my ($self, $step) = @_;

      my $args = $step->args();
      my $thing = $self->thing();

     .. Do some stuff and return the next step to execute ..

      return $step->update({ what => 'do_stuff2', when => DateTime->... , args => [ 'some', 'args' ] });
  }

  sub do_stuff2{
      .. Do some stuff and terminate the process for ever  ..
       return $step->delete();
  }

  __PACKAGE__->meta->make_immutable();

Then in you main application:

   my $longsteps = Schedule::LongSteps->new();
   ...
   $longsteps->instanciate_process('My::Application::MyLongProcess', [ some, init, args ]);

Then regularly (in a cron, or a recurring callback):

  my $long_steps = Schedule::LongSteps->new(...);
  ...

  my $steps = $long_steps->due_steps();
  while( my $step = $steps->next() ){
    $step->execute({ thing => 'whatever' });
  }


=cut

1;
