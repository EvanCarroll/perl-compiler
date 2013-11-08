#!./perl

BEGIN {
    unshift @INC, './lib';
    require './test.pl';
}

use strict;
use warnings;
use vars qw($fh @fh %fh);

eval 'opendir(NOSUCH, "no/such/directory");';
skip_all($@) if $@;

for my $i (1..2000) {
    local *OP;
    opendir(OP, "op") or die "can't opendir: $!";
    # should auto-closedir() here
}

is(opendir(OP, "op"), 1);
my @D = grep(/^[^\.].*\.t$/i, readdir(OP));
closedir(OP);

my $expect;
{
    while (<DATA>) {
	++$expect if m!^CORE/op/[^/]+!;
    }
}

my ($min, $max) = ($expect - 10, $expect + 10);
within(scalar @D, $expect, 10, 'counting op/*.t');

my @R = sort @D;
my @G = sort <op/*.t>;
if ($G[0] =~ m#.*\](\w+\.t)#i) {
    # grep is to convert filespecs returned from glob under VMS to format
    # identical to that returned by readdir
    @G = grep(s#.*\](\w+\.t).*#op/$1#i,<op/*.t>);
}
while (@R && @G && $G[0] eq 'op/'.$R[0]) {
	shift(@R);
	shift(@G);
}
is(scalar @R, 0, 'readdir results all accounted for');
is(scalar @G, 0, 'glob results all accounted for');

is(opendir($fh, "op"), 1);
is(ref $fh, 'GLOB');
is(opendir($fh[0], "op"), 1);
is(ref $fh[0], 'GLOB');
is(opendir($fh{abc}, "op"), 1);
is(ref $fh{abc}, 'GLOB');
isnt("$fh", "$fh[0]");
isnt("$fh", "$fh{abc}");

# See that perl does not segfault upon readdir($x="."); 
# http://rt.perl.org/rt3/Ticket/Display.html?id=68182
fresh_perl_like(<<'EOP', qr/^Bad symbol for dirhandle at/, {}, 'RT #68182');
    my $x = ".";
    my @files = readdir($x);
EOP

done_testing();

__DATA__
CORE/op/64bitint.t
CORE/op/alarm.t
CORE/op/anonsub.t
CORE/op/append.t
CORE/op/args.t
CORE/op/arith.t
CORE/op/array_base.t
CORE/op/array.t
CORE/op/assignwarn.t
CORE/op/attrhand.t
CORE/op/attrs.t
CORE/op/auto.t
CORE/op/avhv.t
CORE/op/bless.t
CORE/op/blocks.subtest.t
CORE/op/blocks.t
CORE/op/bop.t
CORE/op/caller.t
CORE/op/chars.t
CORE/op/chdir.t
CORE/op/chop.t
CORE/op/chr.t
CORE/op/closure.subtest.t
CORE/op/closure.t
CORE/op/cmp.t
CORE/op/concat2.subtest.t
CORE/op/concat2.t
CORE/op/concat.t
CORE/op/cond.t
CORE/op/context.t
CORE/op/cproto.t
CORE/op/crypt.t
CORE/op/dbm.subtest.t
CORE/op/dbm.t
CORE/op/defins.t
CORE/op/delete.t
CORE/op/die_except.t
CORE/op/die_exit.t
CORE/op/die_keeperr.t
CORE/op/die.t
CORE/op/die_unwind.t
CORE/op/dor.t
CORE/op/do.t
CORE/op/each_array.t
CORE/op/each.t
CORE/op/eval.subtest.t
CORE/op/eval.t
CORE/op/exec.t
CORE/op/exists_sub.t
CORE/op/exp.t
CORE/op/fh.t
CORE/op/filehandle.t
CORE/op/filetest_stack_ok.t
CORE/op/filetest.t
CORE/op/filetest_t.t
CORE/op/flip.t
CORE/op/fork.t
CORE/op/getpid.t
CORE/op/getppid.t
CORE/op/gmagic.t
CORE/op/goto.t
CORE/op/grent.t
CORE/op/grep.t
CORE/op/groups.t
CORE/op/gv.t
CORE/op/hashassign.t
CORE/op/hash.t
CORE/op/hashwarn.t
CORE/op/inccode.t
CORE/op/inccode-tie.t
CORE/op/incfilter.t
CORE/op/inc.t
CORE/op/index.subtest.t
CORE/op/index.t
CORE/op/index_thr.t
CORE/op/int.t
CORE/op/join.t
CORE/op/kill0.t
CORE/op/lc.t
CORE/op/lc_user.t
CORE/op/leaky-magic.subtest.t
CORE/op/leaky-magic.t
CORE/op/length.t
CORE/op/lex_assign.t
CORE/op/lex.t
CORE/op/lfs.t
CORE/op/list.t
CORE/op/localref.t
CORE/op/local.t
CORE/op/loopctl.t
CORE/op/lop.t
CORE/op/magic-27839.t
CORE/op/magic_phase.t
CORE/op/magic.subtest.t
CORE/op/magic.t
CORE/op/method.t
CORE/op/mkdir.t
CORE/op/mydef.t
CORE/op/my_stash.t
CORE/op/my.t
CORE/op/negate.t
CORE/op/not.t
CORE/op/numconvert.t
CORE/op/oct.t
CORE/op/ord.t
CORE/op/or.t
CORE/op/overload_integer.t
CORE/op/override.t
CORE/op/packagev.t
CORE/op/pack.t
CORE/op/pos.t
CORE/op/pow.t
CORE/op/print.subtest.t
CORE/op/print.t
CORE/op/protowarn.t
CORE/op/push.t
CORE/op/pwent.t
CORE/op/qq.t
CORE/op/qr.t
CORE/op/quotemeta.t
CORE/op/rand.t
CORE/op/range.t
CORE/op/readdir.subtest.t
CORE/op/readdir.t
CORE/op/readline.subtest.t
CORE/op/readline.t
CORE/op/read.t
CORE/op/recurse.t
CORE/op/ref.subtest.t
CORE/op/ref.t
CORE/op/repeat.t
CORE/op/require_errors.t
CORE/op/reset.t
CORE/op/reverse.t
CORE/op/runlevel.t
CORE/op/setpgrpstack.t
CORE/op/sigdispatch.t
CORE/op/sleep.t
CORE/op/smartkve.t
CORE/op/smartmatch.t
CORE/op/sort.t
CORE/op/splice.t
CORE/op/split.t
CORE/op/split_unicode.t
CORE/op/sprintf2.subtest.t
CORE/op/sprintf2.t
CORE/op/sprintf.t
CORE/op/srand.t
CORE/op/sselect.t
CORE/op/stash.subtest.t
CORE/op/stash.t
CORE/op/state.t
CORE/op/stat.t
CORE/op/study.t
CORE/op/studytied.t
CORE/op/sub_lval.subtest.t
CORE/op/sub_lval.t
CORE/op/sub.t
CORE/op/svleak.t
CORE/op/switch.t
CORE/op/symbolcache.t
CORE/op/sysio.t
CORE/op/taint.t
CORE/op/tiearray.t
CORE/op/tie_fetch_count.t
CORE/op/tiehandle.t
CORE/op/tie.t
CORE/op/time_loop.t
CORE/op/time.t
CORE/op/tr.subtest.t
CORE/op/tr.t
CORE/op/turkish.t
CORE/op/undef.t
CORE/op/universal.subtest.t
CORE/op/universal.t
CORE/op/unshift.t
CORE/op/upgrade.t
CORE/op/utf8cache.t
CORE/op/utf8decode.t
CORE/op/utf8magic.t
CORE/op/utfhash.t
CORE/op/utftaint.t
CORE/op/vec.t
CORE/op/ver.t
CORE/op/wantarray.t
CORE/op/warn.subtest.t
CORE/op/warn.t
CORE/op/while_readdir.t
CORE/op/write.t
CORE/op/yadayada.t
