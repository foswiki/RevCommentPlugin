# ---+ Extensions
# ---++ RevCommentPlugin
# This is the configuration used by the <b>RevCommentPlugin</b>.

# **BOOLEAN**
# Set this to true to enable update revision comments when a file is uploaded.
$Foswiki::cfg{RevCommentPlugin}{AttachmentComments} = 1;

# **BOOLEAN**
# Enable legacy mode in case you upgrade from a previous version of the plugin.
# Leave it to zero to store comments the new way.
$Foswiki::cfg{RevCommentPlugin}{LegacyMode} = 0;

1;
