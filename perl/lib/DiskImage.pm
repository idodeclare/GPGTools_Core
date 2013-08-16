package DiskImage;

use Carp;
use File::Basename;

sub create {
    my($self, %args) = @_;

    my($volname)   =  delete $args{'name'};
    my($volsize)   =  delete $args{'size'};
    my($volfs)     = (delete $args{'fs'}     or 'HFS+');
    my($srcfolder) =  delete $args{'src'};
    my($dmgpath)   =  delete $args{'dmg'};

    carp "Unexpected key ".join(',', keys %args)
        if %args;
    croak "Need a destination path"
        unless $dmgpath;
    croak "Destination path $dmgpath already exists!"
        if -e $dmgpath;

    my(@cmd) = qw(hdiutil create);
    push(@cmd, '-size', $volsize) if $volsize;
    push(@cmd, '-fs', $volfs) if $volfs;
    push(@cmd, '-volname', $volname) if $volname;
#    push(@cmd, qw(-uid 99 -gid 99));   # uid/gid 99 is magic; see man hdid(8)
    if (defined($srcfolder)) {
        if (ref $srcfolder) {
            push(@cmd, '-srcfolder', $_) foreach @$srcfolder;
        } else {
            push(@cmd, '-srcfolder', $srcfolder);
        }
        push(@cmd, '-format', 'UDRW', '-anyowners');
    }
    push(@cmd, $dmgpath);
    system(@cmd) == 0
        or die "'hdiutil create' failed";

    bless({
        dmg => $dmgpath,
        devices => undef
    }, $self);
}

sub mountdir {
    my($self) = shift @_;
    $self->{mountdir} = shift @_ if @_;
    return $self->{mountdir};
}

sub attach {
    my($self) = @_;
    my($warned) = 0;
    my($mountdir) = ( $self->{mountdir} or $ENV{'TMPDIR'} );

    undef $mountdir unless ( $mountdir && -d $mountdir && -w _ );

    open(ATTACH, '-|', 'hdiutil', 'attach',
         '-nobrowse',
         ($mountdir? ('-mountrandom', $mountdir ) : () ),
         $self->{dmg}) or die;
    
    my($devices) = { };
    
    while(<ATTACH>) {
        chomp;
        my(@parts) = split("\t", $_);
        s/ +$// foreach @parts;
        if (2 <= @parts && $parts[0] =~ m-^/dev/-) {
            my($dev) = $parts[0];
            warn "warning: Putative device file '$dev' does not exist\n"
                unless ( -e $dev && ! -f _ );
            my($inf) = {
                type => $parts[1],
            };
            if ($parts[2]) {
                $inf->{mountpoint} = $parts[2] ;
                warn "warning: Putative mount point '$parts[2]' is not a directory\n"
                    unless -d $parts[2];
            }
            $devices->{$dev} = $inf;
        } else {
            warn "hdiutil attach: unexpected output:\n"
                unless $warned;
            $warned ++;
            warn "$_\n";
        }
    }
    
    close(ATTACH)
        or die "'hdiutil attach' failed, died";
    
    $self->{devices} = $devices;

    1;
}

sub mountpoint {
    my($self) = @_;

    my(@p) = grep { $_->{mountpoint} } values %{$self->{devices}};
    return undef unless @p;
    $p[0]->{mountpoint};
}

sub detach {
    my($self) = @_;
    my(@devnodes) = sort { length($a) <=> length($b) } keys %{$self->{devices}};

    system('hdiutil', 'detach', $devnodes[0]) == 0
        or die "'hdiutil detach' failed, died";
    
    1;
}

sub convert {
    my($self, $newfmt, $outfile) = @_;

    system('hdiutil', 'convert', '-format', $newfmt, '-o', $outfile, $self->{dmg}) == 0
        or die "'hdiutil convert' failed, died";
}

sub udifrez {
    my($self, @rsrcs) = @_;

    # Annoyingly, "hdiutil udifrez" doesn't seem to take the simpler Rez
    # format (although udifderez can emit it), so emit an XML plist.
    my($rezfh, $rezfn) = tempfile("rezXXXXX", SUFFIX => '.xml', UNLINK => 1);
    $rezfh->write('<?xml version="1.0" encoding="UTF-8"?>' . "\n" .
                  '<plist version="1.0">' . "\n" . '<dict>');
    
    my(%by_name);
    foreach my $rez (@rsrcs) {
        push(@{$by_name{$rez->{name}}}, $rez);
    }

    foreach my $rezk (sort keys %by_name) {
        $rezfh->write("<key>$rezk</key><array>\n");
        foreach my $rez (@{$by_name{$rezk}}) {
            $rezfh->write('<dict>');
            foreach my $str (qw( Attributes ID Name )) {
                $rezfh->write("<key>$str</key><string>" .
                              $rez->{$str} .
                              "</string>\n")
                    if exists $rez->{$str};
            }
            $rezfh->write("<key>Data</key><data>\n");
            $rezfh->write(MIME::Base64::encode_base64($rez->{Data}));
            $rezfh->write("</data>\n</dict>\n");
        }
        $rezfh->write("</array>\n");
    }

    $rezfh->write("</dict></plist>\n");
    $rezfh->flush;

    die "$rezfn: error writing, died" if $rezfh->error;
    
    system('hdiutil', 'udifrez', $self->{dmg}, '-xml', $rezfn) == 0
        or die "'hdiutil udifrez' failed, died";
    
    1;
}

1;
