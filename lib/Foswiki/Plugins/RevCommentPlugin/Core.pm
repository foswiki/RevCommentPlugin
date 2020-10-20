# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005 by TWiki:Main.JChristophFuchs
# Copyright (C) 2008-2020 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

# =========================
package Foswiki::Plugins::RevCommentPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Time ();

use constant TRACE => 0;    # toggle me

# =========================
sub new {
    my $class   = shift;
    my $session = shift;

    my $this = bless(
        {
            session => $session,
            attachmentComments =>
              $Foswiki::cfg{RevCommentPlugin}{AttachmentComments} // 1,
            legacyMode => $Foswiki::cfg{RevCommentPlugin}{LegacyMode} // 0,
            @_
        },
        $class
    );

    return $this;
}

# =========================
sub setComment {
    my ( $this, $comment ) = @_;

    if ( ref($comment) ) {
        $this->{_revComment} = $comment;
    }
    else {
        $this->{_revComment} = { text => $comment };
    }

    return $this->{_revComment};
}

# =========================
sub beforeSaveHandler {
    my ( $this, $web, $topic, $meta ) = @_;

    print STDERR "called beforeSaveHandler($web, $topic)\n" if TRACE;

    my $request = Foswiki::Func::getRequestObject();

    my $newComment = {};

    if ( defined $this->{_revComment} ) {
        print STDERR "found registered revcomment\n" if TRACE;

        $newComment = $this->{_revComment};
        undef $this->{_revComment};

    }
    elsif ( defined $request->param("revcomment") ) {
        print STDERR "found revcomment in request\n" if TRACE;

        $newComment = { text => $request->param('revcomment'), };

        $newComment->{minor} = $request->param('dontnotify'),;
    }

    $this->putComment( $meta, $newComment );
}

# =========================
sub beforeUploadHandler {
    my ( $this, $attrs, $meta ) = @_;

    return unless $this->{attachmentComments};

    my $web   = $meta->web;
    my $topic = $meta->topic;

    print STDERR "called beforeUploadHandler($web, $topic)\n" if TRACE;
    my $text;

    if ( $meta->hasAttachment( $attrs->{attachment} ) ) {
        $text = 'updated ' . $attrs->{attachment};
    }
    else {
        $text = 'attached ' . $attrs->{attachment};
    }

    $this->putComment( $meta, { text => $text } );

    $meta->saveAs()
      ; # SMELL: must save here as it is unloaded after all handlers have been called
}

# =========================
sub afterRenameHandler {
    my ( $this, $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic,
        $newAttachment )
      = @_;

    print STDERR
"called afterRenameHandler($oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment)\n"
      if TRACE;

    my $text;
    my $meta;

    if ( $oldWeb eq $newWeb ) {
        if (   $oldTopic eq $newTopic
            && $oldAttachment
            && $oldAttachment ne $newAttachment )
        {
            $text = "attachment renamed from $oldAttachment to $newAttachment";
        }
        else {
            $text = "topic renamed from $oldTopic to $newTopic";
        }
    }
    else {
        if ( $newWeb eq $Foswiki::cfg{TrashWebName} ) {
            if ($oldAttachment) {
                $text = "trashed attachment $oldAttachment";
                ($meta) = Foswiki::Func::readTopic( $oldWeb, $oldTopic );
            }
            else {
                $text = "trashed topic $oldWeb.$oldTopic";
            }
        }
        elsif ( $oldWeb eq $Foswiki::cfg{TrashWebName} ) {
            if ($oldAttachment) {
                $text = "restored attachment $newAttachment";
            }
            else {
                $text = "restored topic to $newWeb.$newTopic";
            }
        }
        else {
            if ( $oldTopic eq $newTopic ) {
                if ($oldAttachment) {
                    $text =
"attachment $oldAttachment moved from web $oldWeb.$oldTopic";
                }
                else {
                    $text = "topic $oldTopic moved from web $oldWeb to $newWeb";
                }
            }
        }
    }

    return unless $text;

    ($meta) = Foswiki::Func::readTopic( $newWeb, $newTopic )
      unless defined $meta;

    print STDERR "... text=$text\n" if TRACE;

    $this->putComment( $meta, { text => $text } );

    $meta->saveAs();    # SMELL: must save again
}

# =========================
sub handleRevComment {
    my ( $this, $params, $topic, $web, $meta ) = @_;

    ( $web, $topic ) =
      Foswiki::Func::normalizeWebTopicName( $params->{web} || $web,
        $params->{topic} || $topic );

    my $wikiName = Foswiki::Func::getWikiName();
    return _inlineError("topic does not exist")
      unless Foswiki::Func::topicExists( $web, $topic );
    return _inlineError("access denied")
      unless Foswiki::Func::checkAccessPermission( "VIEW", $wikiName, undef,
        $topic, $web, $meta );

    my $info = $meta->getRevisionInfo();

    my $header    = $params->{header}    // $params->{pre}       // '';
    my $separator = $params->{separator} // $params->{delimiter} // '';
    my $format    = $params->{format}    // '$text $minor';
    my $footer    = $params->{footer}    // $params->{post}      // '';
    my $minor     = $params->{minor}     // '<i>(minor)</i> ';
    my $rev       = $params->{_DEFAULT}  // $params->{rev};
    my $fromRev   = $params->{from};
    my $toRev     = $params->{to};

    if ( defined $rev ) {
        $fromRev = $toRev = $rev;
    }
    else {
        $fromRev //= $info->{version};
        $toRev   //= $info->{version};
    }

    $fromRev =~ s/^.*?(\d+).*?$/$1/;
    $toRev   =~ s/^.*?(\d+).*?$/$1/;

    $fromRev = 1                if $fromRev < 1;
    $fromRev = $info->{version} if $toRev > $info->{version};
    $toRev   = $info->{version} if $toRev > $info->{version};

    if ( $fromRev > $toRev ) {
        my $tmp = $fromRev;
        $fromRev = $toRev;
        $toRev   = $tmp;
    }

#print STDERR "web=$web, topic=$topic, fromRev=$fromRev, toRev=$toRev\n" if TRACE;

    my $comments = $this->getComments( $meta, $fromRev, $toRev );
    return "" unless $comments;

    my @results = ();
    my $index   = 1;
    foreach my $comment ( sort { $b->{rev} <=> $a->{rev} } values %$comments ) {
        next if $comment->{rev} < $fromRev || $comment->{rev} > $toRev;
        my $line = $format;

        my $encText = Foswiki::entityEncode( $comment->{text} );

        $line =~ s/\$(comment|text)\b/$comment->{text}/g;
        $line =~ s/\$enctext\b/$encText/g;
        $line =~ s/\$rev\b/$comment->{rev}/g;
        $line =~ s/\$epoch\b/$comment->{date}/g;
        $line =~ s/\$author\b/$comment->{author}/g;
        $line =~
s/\$date\b/Foswiki::Time::formatTime($comment->{date}, $Foswiki::cfg{DateManipPlugin}{DefaultDateTimeFormat} || '$longdate')/ge;
        $line =~ s/\$minor\b/$comment->{minor}?$minor:""/ge;
        $line =~ s/\$index\b/$index/g;

        push @results, $line;
        $index++;
    }

    return "" unless @results;

    my $total = scalar( values %$comments );
    my $count = scalar(@results);

    my $result = $header . join( $separator, @results ) . $footer;

    $result =~ s/\$count\b/$count/g;
    $result =~ s/\$total\b/$total/g;

    return Foswiki::Func::decodeFormatTokens($result);
}

# =========================
sub getComments {
    my ( $this, $meta, $fromRev, $toRev ) = @_;

    my $info = $meta->getRevisionInfo();

    $fromRev //= 1;
    $toRev   //= $info->{version};

    print STDERR "called getComments($fromRev, $toRev)\n" if TRACE;

    my $data = $meta->get("REVCOMMENT");

    return $this->getLegacyComments( $meta, $fromRev, $toRev )
      if $this->{legacyMode};

    my %comments = ();

    my $web   = $meta->web;
    my $topic = $meta->topic;

    for ( my $rev = $fromRev ; $rev <= $toRev ; $rev++ ) {
        my ($thisMeta) = Foswiki::Func::readTopic( $web, $topic, $rev );
        my $info = $thisMeta->getRevisionInfo();

        my $data = $thisMeta->get("REVCOMMENT");
        next unless defined $data->{text};

#print STDERR "rev=$rev, text=$data->{text}, minor=".($data->{minor}//0).", date=$info->{date}\n" if TRACE;
        $comments{$rev} = {
            text   => $data->{text},
            minor  => $data->{minor} ? 1 : 0,
            date   => $info->{date},
            author => Foswiki::Func::getWikiName( $info->{author} ),
            rev    => $rev,
        };
    }

    return \%comments;
}

# =========================
sub getLegacyComments {
    my ( $this, $meta, $fromRev, $toRev ) = @_;

    my $code = $meta->get('REVCOMMENT');
    return unless $code;

    my %comments = ();

    for ( my $i = 1 ; $i <= $code->{ncomments} ; ++$i ) {
        my $rev = $code->{ 'rev_' . $i };

        next if $rev < $fromRev || $rev > $toRev;

        $comments{$rev} = {
            minor => $code->{ 'minor_' . $i },
            text  => $code->{ 'comment_' . $i },
            date  => $code->{ 't_' . $i },
            rev   => $rev,
        };
    }

    return \%comments;
}

# =========================
sub putComment {
    my ( $this, $meta, $comment ) = @_;

    return unless defined $comment;

    print STDERR "called putComment(" . ( $comment->{text} // 'undef' ) . ")\n"
      if TRACE;

    if ( $this->{legacyMode} ) {
        my $comments = $this->getComments($meta);

        my $revInfo = $meta->getRevisionInfo();
        $comment->{rev}                    = $revInfo->{version};
        $comment->{date}                   = time();
        $comments->{ $revInfo->{version} } = $comment;

        return $this->putLegacyComments( $meta, $comments );
    }

    $meta->remove('REVCOMMENT');

    my $text = $comment->{text} // '';
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return if $text eq "";    # no revcomment required

    my $args = { text => $text };
    $args->{minor} = 1 if $comment->{minor};

    $meta->put( 'REVCOMMENT', $args );

    return $meta;
}

# =========================
sub putLegacyComments {
    my ( $this, $meta, $comments ) = @_;

    $meta->remove('REVCOMMENT');
    return unless $comments;

    my @comments  = @_;
    my $ncomments = scalar( values %$comments );
    my $args      = { ncomments => $ncomments };

    my $i = 1;
    foreach my $comment ( values %$comments ) {
        $args->{ 'comment_' . $i } = $comment->{text};
        $args->{ 't_' . $i }       = $comment->{date} || 0;
        $args->{ 'minor_' . $i }   = $comments->{minor};
        $args->{ 'rev_' . $i }     = $comments->{rev};
        $i++;
    }

    $meta->put( 'REVCOMMENT', $args );

    return $meta;
}

sub _inlineError {
    return "<span class='foswikiAlert'>$_[0]</span>";
}

1;
