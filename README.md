# Homebrew tap for INN++

[INN++](https://github.com/ecarew/inn2) is INN 2.8, the InterNetNews
news server, converted to C++20 and CMake.  This tap builds it from the
release tarball.

```sh
brew tap ecarew/inn2
brew install inn2-cxx
```

INN runs as the `news` user and binds port 119 through `innbind`, its
one helper owned by root.  Homebrew does not run as root, so after
installing, do the steps `brew info inn2-cxx` prints, once, as an
administrator.

INN's programs are in `$(brew --prefix)/opt/inn2-cxx/libexec/bin`,
its configuration in `$(brew --prefix)/etc/news`, and its data in
`$(brew --prefix)/var/news`.  Upgrades keep configuration and data.
