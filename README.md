weechat-proxy-helper
====================

if you're using this you know what it's for

#THIS IS INCREDIBLY BETA, USE AT YOUR OWN RISK
I don't think that quite communicates how beta this is, so here, have it a few more times.
###THIS IS INCREDIBLY BETA, USE AT YOUR OWN RISK
###THIS IS INCREDIBLY BETA, USE AT YOUR OWN RISK
###THIS IS INCREDIBLY BETA, USE AT YOUR OWN RISK
That should suffice. Now, on to the usage.

basic usage
------------
on a buffer on the server you wish to make an in-weechat prefix mapping from

`/prefix add server <prefix> <dest-server>`

where dest-server is the __exact name__ of the destination server

on a buffer on the server you wish to make a FIFO mapping from

`/prefix add fifo <prefix> <remote_server_name> <directory>`

adds a FIFO mapping from <prefix> on the current server pointing at `<remote_server_name>` that has a FIFO located in `<directory>`

note: this takes the *directory* where the FIFO is located, not the location of the FIFO itself -- it will look for a file matching the glob pattern "weechat\_fifo\_\*" inside of the directory and take the first match

`/prefix list` to list all prefixes (warning, it's currently just a straight JSON dump...)

on a buffer on the server you wish to remove a prefix mapping from

`/prefix del <prefix>`

###note:
the prefixes are a simple string match and may be multi-character

rylee has example prefixes `\ => nexus, [ => dawn, n\ => nexus, dawn\ => dawn`

in `<server: rylee> \Text`
out `<server: nexus> Text`

in `<server: rylee> n\Text`
out `<server: nexus> Text`

in `<server: rylee> dawn\Hello!`
out `<server: dawn> Hello!`

Caveats
------------

- Trailing spaces after prefixes are not removed.
- You are prevented from adding prefixes that will conflict with other prefixes (e.g. adding pfx `\` when you already have a pfx `\Dawn`
- ___PREFIXES ARE PER-SERVER.___
- ___PREFIXES ARE CASE-SENSITIVE.___
