#! perl -wt

use Test::More;

use Schedule::LongSteps::Storage::Memory;
use DateTime;

ok( my $storage = Schedule::LongSteps::Storage::Memory->new() );
ok( ! $storage->prepare_due_steps()->has_next(), "Ok zero due steps");

my $process_id = '12345';

$storage->create_step({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });

ok( $storage->prepare_due_steps()->has_next(), "Ok at least one due step");
ok( ! $storage->prepare_due_steps()->has_next(), "Doing it again gives zero steps");

$storage->create_step({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });
$storage->create_step({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });

my $steps = $storage->prepare_due_steps();
ok( $steps->has_next(), "Ok some steps to do");
while( my $step = $steps->next() ){
    # While we are doing things, any other process would see zero things to do
    ok( ! $storage->prepare_due_steps()->has_next(), "Preparing steps again whilst they are running give zero steps");
}


done_testing();
