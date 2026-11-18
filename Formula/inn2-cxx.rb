class Inn2Cxx < Formula
  desc "InterNetNews news server, converted to C++20 and CMake"
  homepage "https://github.com/ecarew/inn2"
  url "https://github.com/ecarew/inn2/releases/download/v2.8.0-cxx.alpha.5/inn-2.8.0-cxx.alpha.5.tar.gz"
  version "2.8.0-cxx.alpha.5"
  sha256 "703fa53ca3063d2a8c9537859e50de7602b35c1964ae7ad92ab59e85b579c635"
  license all_of: ["ISC", "BSD-3-Clause", "MIT", "GPL-2.0-or-later", :public_domain]

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "boost"
  depends_on "openssl@3"
  depends_on "sqlite"

  uses_from_macos "perl"
  uses_from_macos "zlib"

  # INN's programs (innd, inews, rnews, shlock, ...) stay in libexec, out of
  # Homebrew's bin, as many have generic names.  Paths compiled in use the
  # opt link, so an upgrade does not break a running installation.
  def news_root = opt_libexec
  def news_etc = etc/"news"
  def news_var = var/"news"

  def install
    args = %W[
      -DINN_TESTS=OFF
      -DINN_CCACHE=OFF
      -DINN_PREFIX=#{news_root}
      -DINN_PATH_CONFIG=#{news_etc}
      -DINN_DB_DIR=#{news_var}/db
      -DINN_SPOOL_DIR=#{news_var}/spool
      -DINN_LOG_DIR=#{news_var}/log
      -DINN_RUN_DIR=#{news_var}/run
      -DINN_PATH_TMP=#{news_var}/spool/incoming/tmp
      -DINN_HTTP_DIR=#{news_var}/db/http
      -DINN_MAN_DIR=#{opt_share}/man
      -DINN_DOC_DIR=#{opt_share}/doc/inn2-cxx
      -DINN_PERL_FILTERS=OFF
      -DINN_PYTHON_FILTERS=OFF
      -DINN_TLS=ON
      -DINN_SYSTEMD=OFF
      -DINN_BLOCKLIST=OFF
      -DINN_PATHHOST=@PATHHOST@
    ]
    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja", *args, *std_cmake_args
    system "cmake", "--build", "build"

    # Stage, then move each tree into the keg: compiled-in paths point at
    # opt, etc and var, which an install must not write to.
    stage = buildpath/"stage"
    with_env(DESTDIR: stage.to_s) { system "cmake", "--install", "build" }
    libexec.install Dir["#{stage}#{news_root}/*"]
    share.install Dir["#{stage}#{opt_share}/*"]
    rm_r libexec/"include"
    rm Dir[libexec/"lib/*.a"]

    # Configuration and first-install data are copied into etc and var by
    # post_install, only when absent, so a site's files survive upgrades.
    (pkgshare/"etc").install Dir["#{stage}#{news_etc}/*"]
    pkgshare.install "samples/active.minimal", "samples/newsgroups.minimal"
  end

  # Configuration and first-install data, each copied only when absent, so
  # a site's files survive upgrades.  The history database needs the news
  # user, so it is made in the root steps (caveats).
  post_install_steps do
    mkdir_p "news/db/http", base: :var
    mkdir_p "news/spool/articles", base: :var
    mkdir_p "news/spool/overview", base: :var
    mkdir_p "news/spool/incoming/bad", base: :var
    mkdir_p "news/spool/incoming/tmp", base: :var
    mkdir_p "news/spool/outgoing", base: :var
    mkdir_p "news/spool/archive", base: :var
    mkdir_p "news/spool/innfeed", base: :var
    mkdir_p "news/log/OLD", base: :var
    mkdir_p "news/run", base: :var
    unless_path_exists "news", base: :etc do
      copy "etc", "news", source_base: :pkgshare, target_base: :etc, recursive: true
    end
    unless_path_exists "news/db/active", base: :var do
      copy "active.minimal", "news/db/active", source_base: :pkgshare, target_base: :var
    end
    unless_path_exists "news/db/newsgroups", base: :var do
      copy "newsgroups.minimal", "news/db/newsgroups", source_base: :pkgshare, target_base: :var
    end
    unless_path_exists "news/db/active.times", base: :var do
      touch "news/db/active.times", base: :var
    end
  end

  def caveats
    <<~EOS
      INN++ runs as the news user, and binds port 119 through innbind,
      its one helper owned by root.  Homebrew does not run as root, so do
      these steps once, as an administrator:

        # a news user and group, if the system has none
        sudo dscl . -create /Groups/news PrimaryGroupID 250
        sudo dscl . -create /Users/news UniqueID 250
        sudo dscl . -create /Users/news PrimaryGroupID 250
        sudo dscl . -create /Users/news UserShell /usr/bin/false
        sudo dscl . -create /Users/news NFSHomeDirectory #{news_var}

        sudo chown -R news:news #{news_etc} #{news_var}
        sudo chown root:news #{news_root}/bin/innbind
        sudo chmod 4550 #{news_root}/bin/innbind

        # on a first install: this server's name, and the history database
        sudo sed -i '' "s/@PATHHOST@/$(hostname)/" #{news_etc}/inn.conf
        cd #{news_var}/db && sudo -u news touch history &&
          sudo -u news #{news_root}/bin/makedbz -i -o

      Storage defaults: tradspool articles, tradindexed overview, hisv6
      history (storage.conf, inn.conf).  Configuration is in #{news_etc};
      INN's programs are in #{news_root}/bin.  Start the server with
        sudo -u news #{news_root}/bin/rc.news
      After an upgrade, redo the two innbind commands.
    EOS
  end

  test do
    # innconfval reads inn.conf from etc; check a value it compiled in.
    (testpath/"inn.conf").write (pkgshare/"etc/inn.conf").read.sub("@PATHHOST@", "test.example")
    ENV["INNCONF"] = testpath/"inn.conf"
    assert_equal "test.example",
                 shell_output("#{news_root}/bin/innconfval pathhost").strip
    assert_path_exists news_root/"bin/innd"
    assert_path_exists news_root/"bin/innbind"
  end
end
