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
package Foswiki::Plugins::RevCommentPlugin;

=begin TML

---+ package Foswiki::Plugins::RevCommentPlugin

base class to hook into the foswiki core

=cut

use strict;
use warnings;

use Foswiki::Func    ();
use Foswiki::Plugins ();

our $VERSION = '3.10';
our $RELEASE = '20 Nov 2020';
our $SHORTDESCRIPTION =
  'Allows a short summary of changes to be entered for a new revision';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

initialize the plugin, automatically called during the core initialization process

=cut

sub initPlugin {

    if ( defined &Foswiki::Meta::registerMETA ) {
        Foswiki::Meta::registerMETA('REVCOMMENT');
    }

    Foswiki::Func::registerTagHandler(
        'REVCOMMENT',
        sub {
            return getCore(shift)->handleRevComment(@_);
        }
    );

    return 1;
}

=begin TML

---++ finisPlugin()

clean up after session has finished

=cut

sub finishPlugin {
    undef $core;
}

=begin TML

---++ getCore()

get core of this plugin

=cut

sub getCore {
    my $session = shift;

    unless ( defined $core ) {
        require Foswiki::Plugins::RevCommentPlugin::Core;

        $session ||= $Foswiki::Plugins::SESSION;
        $core = Foswiki::Plugins::RevCommentPlugin::Core->new($session);
    }

    return $core;
}

=begin TML

---++ beforeSaveHandler($text, $topic, $web, $meta )

called before a topic is saved to the store

=cut

sub beforeSaveHandler {
    my ( $topic, $web, $meta ) = @_[ 1 .. 3 ];

    return getCore()->beforeSaveHandler( $web, $topic, $meta );
}

=begin TML

---++ beforeUploadHandler(\%attrHash, $meta )

called before an attachment is uploaded or changed

=cut

sub beforeUploadHandler {
    return getCore()->beforeUploadHandler(@_);
}

=begin TML

---++ afterRenameHandler( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment )

called when a topic or attachment has been renamed

=cut

sub afterRenameHandler {
    return getCore()->afterRenameHandler(@_);
}

=begin TML

---++ setComment($commentOrObj) -> $hash

public api to register a revision comment for the next save operation

example:

<verbatim>
my $comment = Foswiki::Plugins::setComment({
                 text => "revision message",
                 minor => 0 / 1, # optional 
              });
</verbatim>

<verbatim>
my $comment = Foswiki::Plugins::setComment("revision message");
</verbatim>

The =$comment= return value is the object being used in the final
store procedure creating the revision comment. It will be invalidated
once the save handler have been executed. So don't keep hold of them
for too long.

=cut

sub setComment {
    return getCore()->setComment(@_);
}

1;
