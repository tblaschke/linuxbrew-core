class Nss < Formula
  desc "Libraries for security-enabled client and server applications"
  homepage "https://developer.mozilla.org/docs/NSS"
  url "https://ftp.mozilla.org/pub/security/nss/releases/NSS_3_46_RTM/src/nss-3.46.tar.gz"
  sha256 "6b699649d285602ba258a4b0957cb841eafc94eff5735a9da8da0adbb9a10cef"

  bottle do
    cellar :any
    sha256 "337d701f18f0493ee3f3b5ddb53a041438ea1429747e7ef3604f6b19d90dee33" => :mojave
    sha256 "f1d570fd77ab0f27b255e43cb75c7907de8d1f103ef6b78bdc609f7f9d027eb4" => :high_sierra
    sha256 "0bb073e2c3ef371bf83e8a1f3ca12b1e67676e25701fd0eb3fad147200c46377" => :sierra
    sha256 "a4ebb42908c5eee0609b65eed55712a717ecfec0f8624d7b2ec0de2468a6e5a6" => :x86_64_linux
  end

  keg_only <<~EOS
    Firefox can pick this up instead of the built-in library, resulting in
    random crashes without meaningful explanation.

    Please see https://bugzilla.mozilla.org/show_bug.cgi?id=1142646 for details
  EOS

  depends_on "nspr"
  unless OS.mac?
    depends_on "sqlite"
    depends_on "zlib"
  end

  def install
    ENV.deparallelize
    cd "nss"

    args = %W[
      BUILD_OPT=1
      NSS_ALLOW_SSLKEYLOGFILE=1
      NSS_USE_SYSTEM_SQLITE=1
      NSPR_INCLUDE_DIR=#{Formula["nspr"].opt_include}/nspr
      NSPR_LIB_DIR=#{Formula["nspr"].opt_lib}
      USE_64=1
    ]

    # Remove the broken (for anyone but Firefox) install_name
    inreplace "coreconf/Darwin.mk", "-install_name @executable_path", "-install_name #{lib}"
    inreplace "lib/freebl/config.mk", "@executable_path", lib

    system "make", "all", *args

    # We need to use cp here because all files get cross-linked into the dist
    # hierarchy, and Homebrew's Pathname.install moves the symlink into the keg
    # rather than copying the referenced file.
    cd "../dist"
    bin.mkpath
    Dir.glob("*.OBJ/bin/*") do |file|
      cp file, bin unless file.include? ".dylib"
    end

    include_target = include + "nss"
    include_target.mkpath
    Dir.glob("public/{dbm,nss}/*") { |file| cp file, include_target }

    lib.mkpath
    libexec.mkpath
    Dir.glob("*.OBJ/lib/*") do |file|
      if file.include? ".chk"
        cp file, libexec
      else
        cp file, lib
      end
    end
    # resolves conflict with openssl, see #28258
    rm lib/"libssl.a"

    (bin/"nss-config").write config_file
    (lib/"pkgconfig/nss.pc").write pc_file
  end

  test do
    # See: https://developer.mozilla.org/docs/Mozilla/Projects/NSS/tools/NSS_Tools_certutil
    (testpath/"passwd").write("It's a secret to everyone.")
    system "#{bin}/certutil", "-N", "-d", pwd, "-f", "passwd"
    system "#{bin}/certutil", "-L", "-d", pwd
  end

  # A very minimal nss-config for configuring firefox etc. with this nss,
  # see https://bugzil.la/530672 for the progress of upstream inclusion.
  def config_file; <<~EOS
    #!/bin/sh
    for opt; do :; done
    case "$opt" in
      --version) opt="--modversion";;
      --cflags|--libs) ;;
      *) exit 1;;
    esac
    pkg-config "$opt" nss
  EOS
  end

  def pc_file; <<~EOS
    prefix=#{prefix}
    exec_prefix=${prefix}
    libdir=${exec_prefix}/lib
    includedir=${prefix}/include/nss

    Name: NSS
    Description: Mozilla Network Security Services
    Version: #{version}
    Requires: nspr >= 4.12
    Libs: -L${libdir} -lnss3 -lnssutil3 -lsmime3 -lssl3
    Cflags: -I${includedir}
  EOS
  end
end
