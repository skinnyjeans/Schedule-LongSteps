package Schedule::LongSteps::Storage::DynamoDB;

use Moose;
extends qw/Schedule::LongSteps::Storage/;

=head1 NAME

Schedule::LongSteps::Storage::DynamoDB - A DynamoDB backed longstep storage.

=cut

=head1 SYNOPSIS


  my $dynamo_db = Paws->service('DynamoDB', ...); # see Paws

  my $storage = Schedule::LongSteps::Storage::DynamoDB->new({ dynamo_db => $dynamo_db });

=cut

has 'dynamo_db' => (is => 'ro', isa => 'Paws::DynamoDB' , required => 1 );

__PACKAGE__->meta()->make_immutable();

