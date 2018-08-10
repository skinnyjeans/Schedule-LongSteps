#! perl -wt

use Test::More;

use Schedule::LongSteps::Storage::Memory;
use DateTime;

ok( my $storage = Schedule::LongSteps::Storage::Memory->new() );
ok( ! scalar( $storage->prepare_due_processes() ), "Ok zero due steps");

ok( my $process_id =  $storage->create_process({ process_class => 'Blabla', what => 'whatever', run_at =>  DateTime->now() })->id(), "Ok got ID");
ok( $storage->find_process($process_id) );

is( scalar( $storage->prepare_due_processes() ) , 1 );

$storage->create_process({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });
$storage->create_process({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });

my @steps = $storage->prepare_due_processes({run_id => 'i_am_a_teapot'});
ok( scalar( @steps ), "Ok some steps to do");
foreach my $step ( @steps ){
    is($step->run_id, 'i_am_a_teapot', 'prepare_due_process has the supplied run_id');
    # While we are doing things, any other process would see zero things to do
    ok(! scalar( $storage->prepare_due_processes()) , "Preparing steps again whilst they are running give zero steps");
}


done_testing();
