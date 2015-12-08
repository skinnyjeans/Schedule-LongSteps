#! perl -wt

use Test::More;

use Schedule::LongSteps::Storage::Memory;
use DateTime;

ok( my $storage = Schedule::LongSteps::Storage::Memory->new() );
ok( ! $storage->prepare_due_processes()->has_next(), "Ok zero due steps");

my $process_id = '12345';

ok( $storage->create_process({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() })->id(), "Ok got ID");

ok( $storage->prepare_due_processes()->has_next(), "Ok at least one due step");
ok( ! $storage->prepare_due_processes()->has_next(), "Doing it again gives zero steps");

$storage->create_process({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });
$storage->create_process({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });

my $steps = $storage->prepare_due_processes();
ok( $steps->has_next(), "Ok some steps to do");
while( my $step = $steps->next() ){
    # While we are doing things, any other process would see zero things to do
    ok( ! $storage->prepare_due_processes()->has_next(), "Preparing steps again whilst they are running give zero steps");
}


done_testing();
