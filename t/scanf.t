use String::Scanf;

print "1..12\n";

($i, $s, $x) = sscanf('%d %3s %g', ' -5_678     abc 3.14e-99 9');

print 'not ' unless ($i == -5678);
print "ok 1\n";

print 'not ' unless ($s eq 'abc');
print "ok 2\n";

print 'not ' unless ($x == 3.14e-99);
print "ok 3\n";

($x, $y, $z) = sscanf('%i%3[a-e]%2c', ' 42acxde');

print 'not ' unless ($x == 42);
print "ok 4\n";

print 'not ' unless ($y == 'ab');
print "ok 5\n";

print 'not ' unless ($$z[0] == 120 and $$z[1] == 100);
print "ok 6\n";

($a, $b) = sscanf('%2$d %1$d', '12 34');

print 'not ' unless ($a == 34);
print "ok 7\n";

print 'not ' unless ($b == 12);
print "ok 8\n";

($h, $o, $hh, $oo) = sscanf('%x %o %x %o', '0xa_b_c_d 0234_5 3_45_6 45_67');

print 'not ' unless ($h == 0xabcd);
print "ok 9\n";

print 'not ' unless ($o == 02345);
print "ok 10\n";

print 'not ' unless ($hh == 0x3456);
print "ok 11\n";

print 'not ' unless ($oo == 04567);
print "ok 12\n";

# eof

