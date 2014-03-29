weechat-proxy-helper
====================

if you're using this you know what it's for

basic usage
------------
on a buffer on the server you wish to make a prefix mapping from
`/addprefix <prefix> <dest-server>`
where dest-server is the __exact name__ of the destination server

`/listprefixes` to list all prefixes (warning, it's currently just a straight JSON dump...)

on a buffer on the server you wish to remove a prefix mapping from
`/delprefix <prefix>`

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
- You are prevented from adding prefixes that will conflict with other prefixes (i.e. adding pfx `\` when you already have a pfx `\Dawn`
