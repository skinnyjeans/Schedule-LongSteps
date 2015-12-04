#! perl -wt

use Test::More;

use_ok('Schedule::LongSteps');
use_ok('Schedule::LongSteps::Storage::Memory');
use_ok('Schedule::LongSteps::Storage::DBIxClass');

done_testing();
