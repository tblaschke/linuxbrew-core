class Sip < Formula
  desc "Tool to create Python bindings for C and C++ libraries"
  homepage "https://www.riverbankcomputing.com/software/sip/intro"
  url "https://dl.bintray.com/homebrew/mirror/sip-4.19.8.tar.gz"
  mirror "https://downloads.sourceforge.net/project/pyqt/sip/sip-4.19.8/sip-4.19.8.tar.gz"
  sha256 "7eaf7a2ea7d4d38a56dd6d2506574464bddf7cf284c960801679942377c297bc"
  revision 13
  head "https://www.riverbankcomputing.com/hg/sip", :using => :hg

  bottle do
    cellar :any_skip_relocation
    sha256 "71d9019466c962dde531b0f82f7d85475c9cb3dfa08bd478d155c0dc7fbe22bf" => :mojave
    sha256 "08903d4a37f0381a950bd53e61dd58e23a7de51164f3d35bcb46a18249e474c6" => :high_sierra
    sha256 "3414722259b7ca140c9ec7662caa9fc154ab42f0000fc2c57c817529002cd2c0" => :sierra
    sha256 "a7ed7d39b9b66323afb8b6f215e4faeb82806783845cbd7a98e4a620008a9e9a" => :x86_64_linux
  end

  depends_on "python"

  def install
    ENV.prepend_path "PATH", Formula["python"].opt_libexec/"bin"
    ENV.delete("SDKROOT") # Avoid picking up /Application/Xcode.app paths

    if build.head?
      # Link the Mercurial repository into the download directory so
      # build.py can use it to figure out a version number.
      ln_s cached_download/".hg", ".hg"
      # build.py doesn't run with python3
      system "python", "build.py", "prepare"
    end

    version = Language::Python.major_minor_version "python3"
    system "python3", "configure.py",
                     *("--deployment-target=#{MacOS.version}" if OS.mac?),
                      "--destdir=#{lib}/python#{version}/site-packages",
                      "--bindir=#{bin}",
                      "--incdir=#{include}",
                      "--sipdir=#{HOMEBREW_PREFIX}/share/sip"
    system "make"
    system "make", "install"
    system "make", "clean"
  end

  def post_install
    (HOMEBREW_PREFIX/"share/sip").mkpath
  end

  def caveats; <<~EOS
    The sip-dir for Python is #{HOMEBREW_PREFIX}/share/sip.
  EOS
  end

  test do
    (testpath/"test.h").write <<~EOS
      #pragma once
      class Test {
      public:
        Test();
        void test();
      };
    EOS
    (testpath/"test.cpp").write <<~EOS
      #include "test.h"
      #include <iostream>
      Test::Test() {}
      void Test::test()
      {
        std::cout << "Hello World!" << std::endl;
      }
    EOS
    (testpath/"test.sip").write <<~EOS
      %Module test
      class Test {
      %TypeHeaderCode
      #include "test.h"
      %End
      public:
        Test();
        void test();
      };
    EOS
    (testpath/"generate.py").write <<~EOS
      from sipconfig import SIPModuleMakefile, Configuration
      m = SIPModuleMakefile(Configuration(), "test.build")
      m.extra_libs = ["test"]
      m.extra_lib_dirs = ["."]
      m.generate()
    EOS
    (testpath/"run.py").write <<~EOS
      from test import Test
      t = Test()
      t.test()
    EOS
    if OS.mac?
      system ENV.cxx, "-shared", "-Wl,-install_name,#{testpath}/libtest.dylib",
                    "-o", "libtest.dylib", "test.cpp"
    else
      system ENV.cxx, "-fPIC", "-shared", "-Wl,-soname,#{testpath}/libtest.so",
                    "-o", "libtest.so", "test.cpp"
    end
    system bin/"sip", "-b", "test.build", "-c", ".", "test.sip"

    version = Language::Python.major_minor_version "python3"
    ENV["PYTHONPATH"] = lib/"python#{version}/site-packages"
    system "python3", "generate.py"
    system "make", "-j1", "clean", "all"
    system "python3", "run.py"
  end
end
