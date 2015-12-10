package Schedule::LongSteps::Storage::DBIxClass;

use Moose;
extends qw/Schedule::LongSteps::Storage/;

use DateTime;

has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1);
has 'resultset_name' => ( is => 'ro', isa => 'Str', required => 1);

sub _get_resultset{
    my ($self) = @_;
    return $self->schema()->resultset($self->resultset_name());
}

=head1 NAME

Schedule::LongSteps::Storage::DBIxClass - DBIx::Class based storage.

=head1 SYNOPSIS

First instanciate a storage with your L<DBIx::Class::Schema> and the name
of the resultset that represent the stored process:

  my $storage = Schedule::LongSteps::Storage::DBIxClass->new({
                   schema => $dbic_schema,
                   resultset_name => 'LongstepsProcess'
                });

Then build and use a L<Schedule::LongSteps> object:

  my $long_steps = Schedule::LongSteps->new({ storage => $storage });

  ...

=head1 RESULTSET REQUIREMENTS

The resultset to use with this storage MUST contain the following columns, constraints and indices:

=over

=item id

A unique primary key auto incrementable identifier

=item process_class

A VARCHAR long enough to hold  your L<Schedule::LongSteps::Process> class names. NOT NULL.

=item what

A VARCHAR long enough to hold the name of one of your steps. Can be NULL.

=item status

A VARCHAR(50) NOT NULL, defaults to 'pending'

=item run_at

A Datetime (or timestamp with timezone in PgSQL). Will hold a UTC Timezoned date of the next run. Default to NULL.

Please index this so it is fast to select a range.

=item run_id

A CHAR or VARCHAR (at least 36). Default to NULL.

Please index this so it is fast to select rows with a matching run_id

=item state

A Reasonably long TEXT field (or JSON field in supporting databases) capable of holding
a JSON dump of pure Perl data. NOT NULL.

You HAVE to implement inflating and deflating yourself. See L<DBIx::Class::InflateColumn::Serializer::JSON>
or similar techniques.

See t/fullblown.t for a full blown working example.

=item error

A reasonably long TEXT field capable of holding a full stack trace in case something goes wrong. Defaults to NULL.

=back

=cut

=head2 prepare_due_processes

See L<Schedule::LongSteps::Storage::DBIxClass>

=cut

sub prepare_due_processes{
    my ($self) = @_;

    my $now = DateTime->now();
    my $rs = $self->_get_resultset();
    my $dtf = $self->schema()->storage()->datetime_parser();

    my $uuid = $self->uuid()->create_str();

    # Move the due ones to a specific 'transient' running status
    $rs->search({
       run_at => { '<=' => $dtf->format_datetime( $now ) },
       run_id => undef,
    })->update({
        run_id => $uuid,
        status => 'running'
    });

    # And return them as a resultset
    return $rs->search({
        run_id => $uuid,
    });
}

=head2 create_process

See L<Schedule::LongSteps::Storage>

=cut

sub create_process{
    my ($self, $process_properties) = @_;
    return $self->_get_resultset()->create($process_properties);
}

=head2 find_process

See L<Schedule::LongSteps::Storage>

=cut

sub find_process{
    my ($self, $process_id) = @_;
    return $self->_get_resultset()->find({ id => $process_id });
}

__PACKAGE__->meta->make_immutable();
