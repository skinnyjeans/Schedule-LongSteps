#! perl -wt

use Test::More;
use Schedule::LongSteps;

{
    package MyProcess;
    use Moose;
    extends qw/Schedule::LongSteps::Process/;

    use DateTime;
    sub build_first_step{
        my ($self) = @_;
        return $self->new_step({ what => 'do_stuff1', run_at => DateTime->now() });
    }

    sub do_stuff1{
        my ($self) = @_;
        return $self->final_step({ state => { the => 'final', state => 1 }  }) ;
    }
}


ok( my $long_steps = Schedule::LongSteps->new() );

ok( my $step = $long_steps->instanciate_process('MyProcess', undef, { beef => 'saussage' }) );

is( $step->what() , 'do_stuff1' );
is_deeply( $step->state() , { beef => 'saussage' });

# Time to run!
ok( $long_steps->run_due_steps() );

# And check the step properties have been
is_deeply( $step->state(), { the => 'final', state => 1 });
is( $step->status() , 'terminated' );
is( $step->run_at() , undef );

# Check no due step have run again
ok( ! $long_steps->run_due_steps() );

done_testing();
