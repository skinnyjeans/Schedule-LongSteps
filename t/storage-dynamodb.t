#! perl -wt

use Test::More;

use Schedule::LongSteps::Storage::DynamoDB;
use DateTime;
use Class::Load;

use Log::Any::Adapter qw/Stderr/;


my @paws_class = ( 'Paws',
                   'Paws::Credential::Explicit',
                   'Paws::Net::LWPCaller' );

join( '', map{ Class::Load::try_load_class( $_ ) ? 'yes' : '' } @paws_class ) eq 'yesyesyes'
    or plan skip_all => "Paws required to run these tests";

$ENV{AWS_ACCESS_KEY} && $ENV{AWS_SECRET_KEY}
    or plan skip_all => "Test requires AWS_ACCESS_KEY and AWS_SECRET_KEY";


my $dynamo_config = {
    region => 'eu-west-1',
    access_key => $ENV{AWS_ACCESS_KEY},
    secret_key => $ENV{AWS_SECRET_KEY},
};


my $credentials = Paws::Credential::Explicit->new($dynamo_config);
my $caller = Paws::Net::LWPCaller->new();

my $dynamo_db = Paws->service(
    'DynamoDB',
    credentials => $credentials,
    caller => $caller,
    max_attempts => 10,
    %{$dynamo_config}
);

ok( my $storage = Schedule::LongSteps::Storage::DynamoDB->new({ dynamo_db => $dynamo_db, table_prefix => 'testdeletethis' }) );
like( $storage->table_name() , qr/^testdeletethis_Schedule_LongSteps_Storage_DynamoDB/ );
is( $storage->table_status() , undef ,"Ok no table exists remotely");
ok( $storage->vivify_table() , "Ok can vivify table");

# ok( ! scalar( $storage->prepare_due_processes() ), "Ok zero due steps");

# ok( my $process_id =  $storage->create_process({ process_class => 'Blabla', what => 'whatever', run_at =>  DateTime->now() })->id(), "Ok got ID");
# ok( $storage->find_process($process_id) );

# is( scalar( $storage->prepare_due_processes() ) , 1 );

# $storage->create_process({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });
# $storage->create_process({ process_class => 'Blabla', process_id => $process_id, what => 'whatever', run_at =>  DateTime->now() });

# my @steps = $storage->prepare_due_processes();
# ok( scalar( @steps ), "Ok some steps to do");
# foreach my $step ( @steps ){
#     # While we are doing things, any other process would see zero things to do
#     ok(! scalar( $storage->prepare_due_processes()) , "Preparing steps again whilst they are running give zero steps");
# }

ok( $storage->destroy_table('I am very sure and I am not insane'), "Ok can destroy table");

done_testing();
