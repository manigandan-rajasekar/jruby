require 'rbconfig'

class MSpecScript

  def self.windows?
    ENV.key?('WINDIR') || ENV.key?('windir')
  end

  def self.linux?
    RbConfig::CONFIG['host_os'] == 'linux'
  end

  set :target, File.expand_path("../../../bin/jruby#{windows? ? '.bat' : ''}", __FILE__)

  if ARGV[-2..-1] != %w[-t ruby] # No flags for MRI
    set :flags, %w[-X+T -J-ea -J-esa -J-Xmx2G -Xtruffle.graal.warn_unless=false]
  end

  set :capi, [
    "spec/ruby/optional/capi",

    # Incorrect C code for spec?
    "^spec/ruby/optional/capi/data_spec.rb",

    # Requires 'ruby/encoding.h'
    "^spec/ruby/optional/capi/encoding_spec.rb",

    # Requires 'ruby/io.h'
    "^spec/ruby/optional/capi/io_spec.rb",

    # Incorrect C code for spec?
    "^spec/ruby/optional/capi/proc_spec.rb",

    # Requires 'ruby/re.h'
    "^spec/ruby/optional/capi/regexp_spec.rb",

    # Requires 'ruby/intern.h'
    "^spec/ruby/optional/capi/struct_spec.rb",

    # Requires 'ruby/thread.h'
    "^spec/ruby/optional/capi/thread_spec.rb",

    # Missing symbol @Init_typed_data_spec.
    "^spec/ruby/optional/capi/typed_data_spec.rb"
  ]

  set :command_line, [
    "spec/ruby/command_line"
  ]

  set :language, [
    "spec/ruby/language"
  ]

  set :core, [
    "spec/ruby/core"
  ]

  set :library, [
    "spec/ruby/library",
    
    # Since 2.3
    "^spec/ruby/library/resolv",
    "^spec/ruby/library/drb",

    # Not yet explored
    "^spec/ruby/library/continuation",
    "^spec/ruby/library/mathn",
    "^spec/ruby/library/readline",
    "^spec/ruby/library/syslog",

    # Doesn't exist as Ruby code - basically need to write from scratch
    "^spec/ruby/library/win32ole",

    # Uses the Rubinius FFI generator
    "^spec/ruby/library/etc",

    # Hangs
    "^spec/ruby/library/net",

    # Load issues with 'delegate'.
    "^spec/ruby/library/delegate/delegate_class/instance_method_spec.rb",
    "^spec/ruby/library/delegate/delegator/protected_methods_spec.rb",

    # Openssl not yet supported
    "^spec/ruby/library/openssl/cipher_spec.rb",
    "^spec/ruby/library/openssl/config/freeze_spec.rb",
    "^spec/ruby/library/openssl/hmac/digest_spec.rb",
    "^spec/ruby/library/openssl/hmac/hexdigest_spec.rb",
    "^spec/ruby/library/openssl/random/pseudo_bytes_spec.rb",
    "^spec/ruby/library/openssl/random/random_bytes_spec.rb",
    "^spec/ruby/library/openssl/x509/name/parse_spec.rb"
  ]

  set :truffle, [
    "spec/truffle/specs"
  ]

  set :backtrace_filter, /mspec\//

  set :tags_patterns, [
    [%r(^.*/command_line/),             'spec/truffle/tags/command_line/'],
    [%r(^.*/language/),                 'spec/truffle/tags/language/'],
    [%r(^.*/core/),                     'spec/truffle/tags/core/'],
    [%r(^.*/library/),                  'spec/truffle/tags/library/'],
    [%r(^.*/optional/capi/),            'spec/truffle/tags/optional/capi/'],
    [%r(^.*/truffle/specs/truffle),     'spec/truffle/tags/truffle/'],
    [/_spec.rb$/,                       '_tags.txt']
  ]

  if windows?
    # exclude specs tagged with 'windows'
    set :xtags, (get(:xtags) || []) + ['windows']
  end

  if linux?
    # exclude specs tagged with 'linux'
    set :xtags, (get(:xtags) || []) + ['linux']
  end

  # Enable features
  MSpec.enable_feature :fiber
  MSpec.enable_feature :fiber_library
  MSpec.disable_feature :continuation_library
  MSpec.disable_feature :fork
  MSpec.enable_feature :encoding

  set :files, get(:language) + get(:core) + get(:library) + get(:truffle)
end

is_child_process = respond_to?(:ruby_exe)
if i = ARGV.index('slow') and ARGV[i-1] == '--excl-tag' and is_child_process
  class SlowSpecsTagger
    def initialize
      MSpec.register :exception, self
    end

    def exception(state)
      if state.exception.is_a? SlowSpecException
        tag = SpecTag.new("slow:#{state.describe} #{state.it}")
        MSpec.write_tag(tag)
      end
    end
  end

  class SlowSpecException < Exception
  end

  require 'timeout'

  slow_methods = [
    [Object, [:ruby_exe, :ruby_cmd]],
    [ObjectSpace.singleton_class, [:each_object]],
    [GC.singleton_class, [:start]],
    [Kernel, [:system]],
    [Kernel.singleton_class, [:system]],
    [Timeout.singleton_class, [:timeout]],
  ]

  slow_methods.each do |klass, meths|
    klass.class_exec do
      meths.each do |meth|
        define_method(meth) do |*args, &block|
          raise SlowSpecException, "Was tagged as slow as it uses #{meth}(). Rerun specs."
        end
        # Keep visibility of Kernel#system
        private meth if klass == Kernel and meth == :system
      end
    end
  end

  SlowSpecsTagger.new
end
