package Schedule::LongSteps::Storage::DynamoDB;

use Moose;
extends qw/Schedule::LongSteps::Storage/;

use Log::Any qw/$log/;
use Scalar::Util;
use MIME::Base64;
use Compress::Zlib;
use JSON;

my $EPOCH_MAX = 2_147_483_647;

=head1 NAME

Schedule::LongSteps::Storage::DynamoDB - A DynamoDB backed longstep storage.

=cut

=head1 SYNOPSIS


  my $dynamo_db = Paws->service('DynamoDB', ...); # see Paws
  # You can also look in t/storage-dynamodb.t for a working example.

  my $storage = Schedule::LongSteps::Storage::DynamoDB->new({ dynamo_db => $dynamo_db, table_prefix => 'my_app_longsteps' });

  # Call that only once as part of your persistent data management:
  $storage->vivify_table();

  my $sl = Schedule::LongSteps->new({ storage => $storage, ... }, ... );

=cut

has 'dynamo_db' => (is => 'ro', isa => 'Paws::DynamoDB' , required => 1 );
has 'table_prefix' => ( is => 'ro', isa => 'Str', required => 1);

has 'table_name' => ( is => 'ro', isa => 'Str', lazy_build => 1);

has 'creation_wait_time' => ( is => 'ro', isa => 'Int', default => 2 );

sub _build_table_name{
    my ($self) = @_;
    my $package = __PACKAGE__;
    $package =~ s/::/_/g;
    return $self->table_prefix().'_'.$package;
}

=head2 table_active

The remote DynamoDB table exists and is active.

=cut

sub table_active{
    my ($self) = @_;
    my $status = $self->table_status();
    unless( defined( $status ) ){ $status = 'NOMATCH'; }
    return $status eq 'ACTIVE';
}

=head2 table_exists

The remote DynamoDB table exists.

=cut

sub table_exists{
    return defined( shift->table_status() );
}

=head2 table_status

Returns the table status (or undef if the table doens't exists at all)

Usage:

  if( my $status = $self->table_status() ){ .. }

Returned status can be one of those described here: L<https://metacpan.org/pod/Paws::DynamoDB::TableDescription>

=cut

sub table_status{
    my ($self) = @_;
    my $desc_table = eval{ $self->dynamo_db()->DescribeTable( TableName => $self->table_name() ) };
    if( my $err = $@ ){
        if( Scalar::Util::blessed($err) &&
            $err->isa('Paws::Exception') &&
            $err->code() eq 'ResourceNotFoundException'
        ){
            $log->debug("No table ".$self->table_name());
            return undef;
        }
        # Rethrow any other error.
        confess( $err );
    }
    return $desc_table->Table()->TableStatus();
}

=head2 vivify_table

Vivifies the remote DynamoDB table to support this storage.

You need to call that at least once as part of your persistent data
management process, or at the beginning of your application.

=cut

sub vivify_table{
    my ($self) = @_;

    my $table_name = $self->table_name();
    if( $self->table_exists() ){
        $log->warn("Table $table_name already exists in remote DynamoDB. Not creating it");
        return;
    }
    # Get all tables and check this one is not there already.
    $log->info("Creating Table ".$table_name." in dynamoDB");

    my $creation = $self->dynamo_db()->CreateTable(
        TableName => $table_name,
        AttributeDefinitions => [
            { AttributeName => 'id', AttributeType => 'S' },
            ## Note those are only there for reference.
            ## as AttributeDefinition must only defined attributes
            ## used in the KeySchema
            # { AttributeName => 'process_class', AttributeType => 'S' },
            # { AttributeName => 'status', AttributeType => 'S' },
            # { AttributeName => 'what', AttributeType => 'S' },
            { AttributeName => 'run_at_day' , AttributeType => 'N' }, # int( Time in epoch / 86400 ) = epoch day
            { AttributeName => 'run_at', AttributeType => 'N' }, # Time in epoch of run_at
            # { AttributeName => 'run_id', AttributeType => 'S' }, # The current run_id
            # { AttributeName => 'state', AttributeType => 'S' },
            # { AttributeName => 'error', AttributeType => 'S' },
        ],
        KeySchema => [
            { AttributeName => 'id', KeyType => 'HASH' },
        ],
        GlobalSecondaryIndexes => [
            {
                IndexName => 'by_run_at_day',
                KeySchema => [
                    { AttributeName => 'run_at_day', KeyType => 'HASH' },
                    { AttributeName => 'run_at', KeyType => 'RANGE' },
                ],
                Projection => {
                    NonKeyAttributes => [ 'run_id' ],
                    ProjectionType => 'INCLUDE'
                },
                ProvisionedThroughput => {
                    ReadCapacityUnits => 2,
                    WriteCapacityUnits => 2,
                }
            }
        ],
        ProvisionedThroughput => {
            ReadCapacityUnits => 2,
            WriteCapacityUnits => 2,
            # This is low to avoid having a large bill in case
            # of tests failure.
            # Note that we can change that AFTER the fact
        },
    );

    while(! $self->table_active() ){
        $log->info("Table $table_name not active yet. Waiting ".$self->creation_wait_time()." second");
        if( $self->creation_wait_time() ){
            sleep($self->creation_wait_time());
        }
    }
    $log->info("Table $table_name ACTIVE. All is fine");
    return $creation;
}

sub prepare_due_processes{
    my ($self) = @_;
    return ();
}

=head2

See L<Schedule::LongSteps::Storage>

=cut

sub create_process{
    my ($self, $properties) = @_;
    my $o = Schedule::LongSteps::Storage::DynamoDB::Process->new({
        storage => $self,
        id => $self->uuid()->create_str(),
        %{$properties}
    });
    $o->_insert();
    return $o;
}

sub find_process{
    my ($self, $pid) = @_;
    my $dynamo_item = $self->dynamo_db()->GetItem(
        TableName => $self->table_name(),
        ConsistentRead => 1, # Very important. We are doing OLTP with this thing.
        Key => {
            id => { S => $pid }
        }
    )->Item();
    unless( $dynamo_item ){
        return undef;
    }
    return $self->_document_from_attrmap( $dynamo_item );
}

sub _decode_state{
    my ($self, $dynamo_state) = @_;
    if( $dynamo_state =~ /^{/ ){
        # Assume JSON
        return JSON::from_json( $dynamo_state );
    }

    # Assume base64 encoded memGunzip
    return JSON::from_json( Compress::Zlib::memGunzip( MIME::Base64::decode_base64( $dynamo_state ) ) );
}

sub _document_from_attrmap{
    my ($self, $dynamoItem) = @_;
    my $map = $dynamoItem->Map();

    my $run_at = $map->{run_at}->N();
    if( $run_at == $EPOCH_MAX ){
        $run_at = undef;
    }else{
        $run_at = DateTime->from_epoch( epoch => $run_at );
    }
    my $run_id = $map->{run_id}->S();
    if( $run_id eq 'NULL' ){
        $run_id = undef;
    }
    my $state = $self->_decode_state( $map->{state}->S() );
    my $error = $map->{error}->S();
    if( $error eq 'NULL' ){
        $error = undef;
    }

    return Schedule::LongSteps::Storage::DynamoDB::Process->new({
        storage => $self,
        id => $map->{id}->S(),
        process_class => $map->{process_class}->S(),
        status => $map->{status}->S(),
        what => $map->{what}->S(),
        run_at => $run_at,
        run_id => $run_id,
        state => $state,
        error => $error,
    });
}


=head2 destroy_table

Destroys this table. Mainly so tests don't leave some crap behind.

Use that responsibly. Which is never except in tests.

Note that this blocks until the table has effectively been deleted remotely.

=cut

sub destroy_table{
    my ($self, $am_i_sure) = @_;
    unless( $am_i_sure eq 'I am very sure and I am not insane' ){
        confess("Sorry we cannot let you do that");
    }
    unless( $self->table_active() ){
        confess("Sorry this table is not ACTIVE. Too early to destroy");
    }
    my $table_name = $self->table_name();
    unless( $table_name =~ /^testdelete/ ){
        confess("Sorry this is not a test table (from the test suite. Destroy manually if you are sure");
    }
    $log->warn("Will destroy $table_name from dynamoDB");
    my $deletion = $self->dynamo_db()->DeleteTable(TableName => $table_name);
    # Wait until the table is effectively destroyed.
    while( $self->table_exists() ){
        $log->warn("Table $table_name not destroyed yet. Waiting ".$self->creation_wait_time()." second");
        if( $self->creation_wait_time() ){
            sleep( $self->creation_wait_time() );
        }
    }
    $log->warn("Table $table_name DESTROYED");
    return $deletion;
}

__PACKAGE__->meta()->make_immutable();

package Schedule::LongSteps::Storage::DynamoDB::Process;

use Moose;

use Log::Any qw/$log/;
use JSON;
use MIME::Base64;
use Compress::Zlib;
use DateTime;

# my $EPOCH_MAX = 2_147_483_647;
my $SECONDS_IN_DAY = 86_400;

has 'storage' => ( is => 'ro', isa => 'Schedule::LongSteps::Storage::DynamoDB', required => 1 );
has 'id' => ( is => 'ro', isa => 'Str', required => 1 );

has 'process_class' => ( is => 'rw', isa => 'Str', required => 1); # rw only for test. Should not changed ever.
has 'status' => ( is => 'rw', isa => 'Str', default => 'pending' );
has 'what' => ( is => 'rw' ,  isa => 'Str', required => 1);
has 'run_at' => ( is => 'rw', isa => 'Maybe[DateTime]', default => sub{ undef; } );
has 'run_id' => ( is => 'rw', isa => 'Maybe[Str]', default => sub{ undef; } );
has 'state' => ( is => 'rw', default => sub{ {}; });
has 'error' => ( is => 'rw', isa => 'Maybe[Str]', default => sub{ undef; } );

sub _insert{
    my ($self) = @_;
    my $table_name = $self->storage()->table_name();

    $log->info("Inserting ".ref($self)." , id = ".$self->id()." in Dynamo table ".$table_name);
    $self->storage()->dynamo_db->PutItem(
        TableName => $table_name,
        Item => $self->_to_dynamo_item(),
    );
    return $self;
}

sub _state_encode{
    my ($self) = @_;
    my $state_json = JSON::to_json(
        $self->state(),
        { ascii => 1 }
    );
    unless( length( $state_json ) > 350_000 ){
        $log->debug("Encoded state is ".substr( $state_json, 0 , 2000 ));
        return $state_json;
    }

    $log->debug("State JSON is over 350KB, compressing");
    my $state_b64zjs = MIME::Base64::encode_base64(
        Compress::Zlib::memGzip( $state_json ) );
    if( length( $state_b64zjs ) > 350_000 ){
        confess("Compressed state is too large (over 350000 bytes)");
    }
    $log->debug("Encoded state is ".substr( $state_b64zjs , 0, 1000 ) .'...' );
    return $state_b64zjs;
}

sub _error_trim{
    my ($self) = @_;
    unless( $self->error() ){
        return undef;
    }
    return substr( $self->error() , 0 , 2000 );
}

sub _to_dynamo_item{
    my ($self) = @_;
    my $run_at_epoch = $EPOCH_MAX;
    if( my $run_at = $self->run_at() ){
        $run_at_epoch = $run_at->epoch();
    }
    my $run_at_epoch_day = int( $run_at_epoch / $SECONDS_IN_DAY );


    return {
        id => { S => $self->id() },
        process_class => { S => $self->process_class() },
        status => { S => $self->status() },
        what => { S => $self->what() },
        run_at_day => { N => $run_at_epoch_day },
        run_at => { N => $run_at_epoch },
        run_id => { S => $self->run_id() || 'NULL' },
        state => { S => $self->_state_encode() },
        error => { S => $self->_error_trim() || 'NULL' },
    }
}

__PACKAGE__->meta()->make_immutable();
