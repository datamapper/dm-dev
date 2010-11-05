#!/usr/bin/env ruby -Ku
# encoding: utf-8

require 'set'
require 'yaml'
require 'fileutils'
require 'pathname'

require 'thor'
require 'addressable/uri'
require 'ruby-github'

class ::Project

  def self.command_names
    %w[ sync bundle:install bundle:update bundle:show gem:install gem:uninstall spec release implode status list ]
  end

  def self.command_name(name)
    command_fragments(name).join('_')
  end

  def self.command_class_name(name)
    command_fragments(name).map { |fragment| fragment.capitalize }.join('::')
  end

  def self.command_fragments(name)
    name.split(':').map { |fragment| fragment }
  end

  command_names.each do |name|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def self.#{command_name(name)}(options = {})
        new(options).send(:#{command_name(name)})
      end

      def #{command_name(name)}

        start = Time.now if env.benchmark?

        self.class.invoke :before, '#{command_name(name)}', env, repos
        @repos.each do |repo|
          @logger.progress!
          command_class('#{name}').new(repo, env, @logger).run
        end
        self.class.invoke :after, '#{command_name(name)}', env, repos

        if env.benchmark?

          elapsed = (Time.now - start).to_i

          puts '-----------------------------------------'
          puts "Time elapsed: \#{formatted_time(elapsed)}"
          puts '-----------------------------------------'
        end
      end
    RUBY
  end

  attr_reader   :env
  attr_reader   :root
  attr_reader   :repos
  attr_reader   :options

  attr_accessor :commands

  def initialize(options = {})
    @options  = options
    @env      = environment_class.new(name, @options)
    @root     = @env.root
    @repos    = Repositories.new(@root, name, @env.included, @env.excluded + excluded_repos)
    @logger   = Logger.new(@env, @repos.count)
    @commands = {}
  end

  def environment_class
    Environment
  end

  def command_class(name)
    return commands[name] if commands[name]
    Utils.full_const_get(self.class.command_class_name(name), Command)
  end

  def self.before(command_name, &block)
    ((@before ||= {})[command_name] ||= []) << block
  end

  def self.after(command_name, &block)
    ((@after ||= {})[command_name] ||= []) << block
  end

  def self.invoke(kind, name, *args)
    hooks = instance_variable_get("@#{kind}")
    return unless hooks && hooks[name]
    hooks[name].each { |hook| hook.call(*args) }
  end

  def formatted_time(time)
    hours   = (time / 3600).to_i
    minutes = (time / 60 - hours * 60).to_i
    seconds = (time - (minutes * 60 + hours * 3600))

    "%02d:%02d:%02d" % [hours, minutes, seconds]
  end

  class Metadata

    attr_reader :root
    attr_reader :name
    attr_reader :repositories

    def self.fetch(root, name)
      new(root, name).repositories
    end

    def initialize(root, name)
      @root, @name  = root, name
      @repositories = fetch
    end

    def fetch
      filename = root.join(config_file_name)
      if filename.file?
        load_from_yaml(filename)
      else
        load_from_github(filename)
      end
    end

    def config_file_name
      'dm-dev.yml'
    end

    def load_from_github(filename)
      cache(GitHub::API.user(name).repositories, filename)
    end

    def load_from_yaml(filename)
      YAML.load(File.open(filename))['repositories'].map do |repo|
        Struct.new(:name, :url).new(repo['name'], repo['url'])
      end
    end

  private

    def cache(repos, filename)
      File.open(filename, 'w') do |f|
        f.write(YAML.dump({
          'repositories' => repos.map { |repo| { 'name' => repo.name, 'url' => repo.url } }
        }))
      end
      repos
    end

  end

  module Utils

    def self.full_const_get(name, root = Object)
      obj = root
      namespaces(name).each do |x|
        # This is required because const_get tries to look for constants in the
        # ancestor chain, but we only want constants that are HERE
        obj = obj.const_defined?(x) ? obj.const_get(x) : obj.const_missing(x)
      end
      obj
    end

    def self.namespaced?(const_name)
      namespaces(const_name).size > 1
    end

    def self.namespaces(const_name)
      path = const_name.to_s.split('::')
      path.shift if path.first.empty?
      path
    end

  end

  class Repositories

    include Enumerable

    def initialize(root, user, repos, excluded_repos)
      @root, @user    = root, user
      @repos          = repos
      @excluded_repos = excluded_repos
      @metadata       = Metadata.fetch(@root, @user)
      @repositories   = selected_repositories.map do |repo|
        Repository.new(@root, repo)
      end
    end

    def each
      @repositories.each { |repo| yield(repo) }
    end

  private

    def selected_repositories
      if use_current_directory?
        @metadata.select { |repo| managed_repo?(repo) }
      else
        @metadata.select { |repo| include_repo?(repo) }
      end
    end

    def managed_repo?(repo)
      repo.name == relative_path_name
    end

    def include_repo?(repo)
      if @repos
        !excluded_repo?(repo) && (include_all? || @repos.include?(repo.name))
      else
        !excluded_repo?(repo)
      end
    end

    def excluded_repo?(repo)
      @excluded_repos.include?(repo.name)
    end

    def use_current_directory?
      @repos.nil? && inside_available_repo? && !include_all?
    end

    def inside_available_repo?
      @metadata.map(&:name).include?(relative_path_name)
    end

    def include_all?
      explicitly_specified = @repos.respond_to?(:each) && @repos.count == 1 && @repos.first == 'all'
      if inside_available_repo?
        explicitly_specified
      else
        @repos.nil? || explicitly_specified
      end
    end

    def relative_path_name
      Pathname(Dir.pwd).relative_path_from(@root).to_s
    end

  end

  class Repository

    attr_reader :path
    attr_reader :name
    attr_reader :uri

    def initialize(root, repo)
      @name = repo.name
      @path = root.join(@name)
      @uri  = Addressable::URI.parse(repo.url)
    end

    def installable?
      path.join('Gemfile').file?
    end

  end

  class Environment

    attr_reader :name
    attr_reader :options
    attr_reader :root
    attr_reader :included
    attr_reader :excluded
    attr_reader :rubies
    attr_reader :bundle_root
    attr_reader :gemset
    attr_reader :command_options

    def initialize(name, options)
      @name            = name
      @options         = options
      @root            = Pathname(@options[:root       ] ||  ENV['DM_DEV_ROOT'       ] || Dir.pwd)
      @bundle_root     = Pathname(@options[:bundle_root] ||  ENV['DM_DEV_BUNDLE_ROOT'] || @root.join(default_bundle_root))
      @included        = @options[:include             ] || (ENV['INCLUDE'           ]  ? normalize(ENV['INCLUDE']) : default_included)
      @excluded        = @options[:exclude             ] || (ENV['EXCLUDE'           ]  ? normalize(ENV['EXCLUDE']) : default_excluded)
      @rubies          = @options[:rubies              ] || (ENV['RUBIES'            ]  ? normalize(ENV['RUBIES' ]) : default_rubies)
      @verbose         = @options[:verbose             ] || (ENV['VERBOSE'           ] == 'true')
      @pretend         = @options[:pretend             ] || (ENV['PRETEND'           ] == 'true')
      @benchmark       = @options[:benchmark           ] || (ENV['BENCHMARK'         ] == 'true')
      @gemset          = @options[:gemset              ] ||  ENV['GEMSET'            ]
      @command_options = @options[:command_options     ] ||  nil
    end

    def default_bundle_root
      'DM_DEV_BUNDLE_ROOT'
    end

    def default_included
      nil # means all
    end

    def default_excluded
      [] # overwrite in subclasses
    end

    def default_rubies
      %w[ 1.8.7 1.9.2 jruby rbx ]
    end

    def verbose?
      @verbose
    end

    def pretend?
      @pretend
    end

    def benchmark?
      @benchmark
    end

  private

    def normalize(string)
      string.gsub(',', ' ').split(' ')
    end

  end

  class Logger

    attr_reader :progress

    def initialize(env, repo_count)
      @env      = env
      @progress = 0
      @total    = repo_count
      @padding  = @total.to_s.length
      @verbose  = @env.verbose?
      @pretend  = @env.pretend?
    end

    def log(repo, action, command = nil, msg = nil)
      command = command.to_s.squeeze(' ').strip # TODO also do for actually executed commands
      if @pretend || @verbose
        puts command
      else
        puts '[%0*d/%d] %s %s %s%s' % format(repo, action, command, msg)
      end
    end

    def progress!
      @progress += 1
    end

    def format(repo, action, command, msg)
      [ @padding, @progress, @total, action, repo.name, msg, @verbose ? ": #{command}" : '' ]
    end

  end

  class Command

    attr_reader :repo
    attr_reader :env
    attr_reader :root
    attr_reader :path
    attr_reader :uri
    attr_reader :logger

    def initialize(repo, env, logger)
      @repo    = repo
      @env     = env
      @root    = @env.root
      @path    = @root.join(@repo.name)
      @uri     = @repo.uri
      @logger  = logger
      @verbose = @env.verbose?
    end

    def before
      # overwrite in subclasses
    end

    def run
      log_directory_change
      FileUtils.cd(working_dir) do
        if block_given?
          yield
        else
          execute
        end
      end
    end

    def after
      # overwrite in subclasses
    end

    def execute
      if executable?
        before
        unless suppress_log?
          log(command)
        end
        unless pretend?
          sleep(timeout)
          system(command)
        end
        after
      else
        if verbose? && !pretend?
          log(command, "SKIPPED! - #{explanation}")
        end
      end
    end

    # overwrite in subclasses
    def command
      raise NotImplementedError
    end

    # overwrite in subclasses
    def executable?
      true
    end

    # overwrite in subclasses
    def suppress_log?
      false
    end

    # overwrite in subclasses
    def explanation
      'reason unknown'
    end

    def log_directory_change
      if needs_directory_change? && (verbose? || pretend?)
        log "cd #{working_dir}"
      end
    end

    def needs_directory_change?
      Dir.pwd != working_dir.to_s
    end

    def ignored?
      ignored_repos.include?(repo.name)
    end

    # overwrite in subclasses
    def ignored_repos
      []
    end

    # overwrite in subclasses
    def working_dir
      path
    end

    def verbose?
      @verbose
    end

    def pretend?
      @env.pretend?
    end

    def verbosity
      verbose? ? verbose : silent
    end

    # overwrite in subclasses
    def verbose
    end

    def silent
      '>& /dev/null'
    end

    # overwrite in subclasses
    def timeout
      0
    end

    # overwrite in subclasses
    def action
    end

    def log(command = nil, msg = nil)
      logger.log(repo, action, command, msg)
    end

    class List < ::Project::Command

      def run
        log
      end

    end

    class Sync < Command

      def self.new(repo, env, logger)
        return super unless self == Sync
        if env.root.join(repo.name).directory?
          Pull.new(repo, env, logger)
        else
          Clone.new(repo, env, logger)
        end
      end


      class Clone < Sync

        def initialize(repo, env, logger)
          super
          @git_uri        = uri.dup
          @git_uri.scheme = 'git'
          if env.options[:development]
            @git_uri.to_s.sub!('://', '@').sub!('/', ':')
          end
        end

        def command
          "git clone #{@git_uri}.git #{verbosity}"
        end

        def working_dir
          root
        end

        def action
          'Cloning'
        end

      end

      class Pull < Sync

        def command
          "git checkout master #{verbosity}; git pull --rebase #{verbosity}"
        end

        def action
          'Pulling'
        end

      end
    end

    class Rvm < Command

      attr_reader :rubies

      def initialize(repo, env, logger)
        super
        @rubies = env.rubies
      end

      def command
        "rvm #{rubies.join(',')}"
      end

      class Exec < Rvm

        attr_reader :ruby

        def run
          super do
            rubies.each do |ruby|
              @ruby = ruby
              if block_given?
                yield(ruby)
              else
                execute
              end
            end
          end
        end

      private

        def command
          "rvm #{@ruby} exec bash -c"
        end

        def action
          "[#{@ruby}]"
        end

      end

    end

    class Bundle < Rvm::Exec

      class Install < Bundle

        def bundle_command
          'install'
        end

        def action
          "#{super} bundle install"
        end

      end

      class Update < Bundle

        def bundle_command
          'update'
        end

        def action
          "#{super} bundle update"
        end

      end

      class Show < Bundle

        def bundle_command
          'show'
        end

        def action
          "#{super} bundle show"
        end

      end


      def initialize(repo, env, logger)
        super
        @bundle_root = env.bundle_root
        rubies.each { |ruby| bundle_path(ruby).mkpath }
      end

      def before
        super
        make_gemfile
      end

      def executable?
        !ignored? && repo.installable?
      end

      def command
        "#{super} \"#{environment} bundle #{bundle_command} #{options} #{verbosity}\""
      end

      def environment
        "BUNDLE_PATH='#{bundle_path(ruby)}' BUNDLE_GEMFILE='#{gemfile}'"
      end

      def bundle_path(ruby)
        @bundle_root.join(ruby)
      end

      def gemfile
        "Gemfile.#{ruby}"
      end

      def make_gemfile
        unless working_dir.join(gemfile).file?
          master = working_dir.join(master_gemfile)
          log "cp #{master} #{gemfile}"
          unless pretend?
            FileUtils.cp(master, gemfile)
          end
        end
      end

      def master_gemfile
        'Gemfile'
      end

      def options
        nil
      end

      def explanation
        if ignored?
          "because it's ignored"
        elsif !repo.installable?
          "because it's missing a Gemfile"
        else
          "reason unknown"
        end
      end

    end

    class Spec < Bundle

      def run

        if print_matrix?
          puts  "\nh2. %s\n\n"   % repo.name
          puts  '| RUBY  | %s |' % env.adapters.join(' | ')
        end

        super do |ruby|

          print '| %s |' % ruby if print_matrix?

          if block_given?

            yield ruby

          else

            execute

            if print_matrix?
              print ' %s |' % [ $?.success? ? 'pass' : 'fail' ]
            end

          end

        end

      end

      def bundle_command
        if env.command_options
          "exec spec #{env.command_options.join(' ')}"
        else
          'exec rake spec'
        end
      end

      def action
        "#{super} Testing"
      end

      def print_matrix?
        executable? && !verbose? && !pretend?
      end

      def suppress_log?
        !executable? || print_matrix?
      end

    end

    class Gem < Rvm

      class Install < Gem

        def command
          "#{super} gem build #{gemspec_file}; #{super} gem install #{gem}"
        end

        def action
          'Installing'
        end

      end

      class Uninstall < Gem

        def command
          "#{super} gem uninstall #{repo.name} --version #{version}"
        end

        def action
          'Uninstalling'
        end

      end

      def before
        create_gemset = "rvm gemset create #{env.gemset}"

        log    create_gemset if verbose?
        system create_gemset if env.gemset && !pretend?
      end

      def rubies
        env.gemset ? super.map { |ruby| "#{ruby}@#{env.gemset}" } : super
      end

      def gem
        "#{working_dir.join(repo.name)}-#{version}.gem"
      end

      def gemspec_file
        "#{working_dir.join(repo.name)}.gemspec"
      end

      def version
        ::Gem::Specification.load(working_dir.join(gemspec_file)).version.to_s
      end

    end

    class Release < Command

      def run
        # TODO move to its own command
        clean_repository(project_name)

        FileUtils.cd(working_dir) do
          log(command)
          system(command) unless pretend?
        end
      end

      def command
        'rake release'
      end

      def action
        'Releasing'
      end

    end

    class Implode < Command

      def run
        log    command
        system command unless pretend?
      end

      def command
        "rm -rf #{working_dir} #{verbosity}"
      end

      def action
        'Deleting'
      end

    end

    class Status < Command

      def run
        log "cd #{working_dir}" if verbose? || pretend?
        FileUtils.cd(working_dir) do
          log    command
          system command unless pretend?
        end
      end

      def command
        "git status"
      end

      def action
        'git status'
      end

    end

  end

end

module DataMapper

  class Project < ::Project

    def initialize(options = {})
      super
      commands['bundle:install'] = DataMapper::Project::Bundle::Install
      commands['bundle:update' ] = DataMapper::Project::Bundle::Update
      commands['bundle:show'   ] = DataMapper::Project::Bundle::Show
      commands['spec']           = DataMapper::Project::Spec
    end

    def name
      'datamapper'
    end

    def environment_class
      DataMapper::Project::Environment
    end

    def excluded_repos
      %w[ dm-more ]
    end

    before 'implode' do |env, repos|
      FileUtils.rm_rf env.bundle_root if env.included.nil? && !env.pretend?
    end

    class Environment < ::Project::Environment

      attr_reader :adapters

      def initialize(name, options)
        super
        @adapters ||= options[:adapters] || (ENV['ADAPTERS'] ? normalize(ENV['ADAPTERS']) : default_adapters)
      end

      def default_adapters
        %w[ in_memory yaml sqlite postgres mysql ]
      end

      def default_excluded
        %w[ dm-oracle-adapter dm-sqlserver-adapter ]
      end

    end

    module Bundle

      def environment
        "#{super} #{support_lib}"
      end

      def support_lib
        ruby == '1.8.6' ? 'EXTLIB="true"' : ''
      end

      def adapters
        env.adapters.join(' ')
      end

      def master_gemfile
        'Gemfile.local'
      end

      def gemfile
        "#{super}#{local_install? ? '.local' : ''}"
      end

      def local_install?
        working_dir.join("Gemfile.local").file?
      end

      def ignored_repos
        %w[ dm-dev data_mapper datamapper.github.com dm-ferret-adapter rails_datamapper ]
      end

      def timeout
        2
      end

      module Manipulation

        def environment
          "#{super} ADAPTERS='#{adapters}'"
        end

      end

      class Install < ::Project::Command::Bundle::Install

        include DataMapper::Project::Bundle
        include DataMapper::Project::Bundle::Manipulation

        def before
          unless local_install?
            log local_gemfile_command
            system local_gemfile_command unless pretend?
          end
          super
        end

        def local_gemfile_command
          "rake local_gemfile #{verbosity}"
        end

        def options
          '--without quality'
        end

      end

      class Update < ::Project::Command::Bundle::Update

        include DataMapper::Project::Bundle
        include DataMapper::Project::Bundle::Manipulation

      end

      class Show < ::Project::Command::Bundle::Show

        include DataMapper::Project::Bundle
        include DataMapper::Project::Bundle::Manipulation

      end

    end

    class Spec < ::Project::Command::Spec

      include DataMapper::Project::Bundle

      def run
        super do |ruby|
          env.adapters.each do |adapter|
            @adapter = adapter # HACK?

            execute

            if print_matrix?
              print ' %s |' % [ $?.success? ? 'pass' : 'fail' ]
            end
          end
          puts if print_matrix?
        end
      end

      def environment
        "#{super} ADAPTER=#{@adapter} TZ=utc"
      end

    end

    # The tasks
    class Tasks < ::Thor

      module CommonOptions
        def self.included(host)
          host.class_eval do
            class_option :root,        :type => :string,  :aliases => '-r', :desc => 'The directory where all DM source code is stored (overwrites DM_DEV_ROOT)'
            class_option :bundle_root, :type => :string,  :aliases => '-B', :desc => 'The directory where bundler stores all its data (overwrites DM_DEV_BUNDLE_ROOT)'
            class_option :rubies,      :type => :array,   :aliases => '-R', :desc => 'The rvm ruby interpreters to use with this command (overwrites RUBIES)'
            class_option :include,     :type => :array,   :aliases => '-i', :desc => 'The DM gems to include with this command (overwrites INCLUDE)'
            class_option :exclude,     :type => :array,   :aliases => '-e', :desc => 'The DM gems to exclude with this command (overwrites EXCLUDE)'
            class_option :adapters,    :type => :array,   :aliases => '-a', :desc => 'The DM adapters to use with this command (overwrites ADAPTERS)'
            class_option :pretend,     :type => :boolean, :aliases => '-p', :desc => 'Print the shell commands that would get executed'
            class_option :verbose,     :type => :boolean, :aliases => '-v', :desc => 'Print the shell commands being executed'
            class_option :benchmark,   :type => :boolean, :aliases => '-b', :desc => 'Print the time the command took to execute'
          end
        end

        def options
          if index = ARGV.index('--')
            super.merge(:command_options => ARGV.slice(index + 1, ARGV.size - 1))
          else
            super
          end
        end

      end

      namespace :dm

      include Thor::Actions
      include CommonOptions

      desc 'sync', 'Sync with the DM repositories'
      method_option :development, :type => :boolean, :aliases => '-d', :desc => 'Use the private github clone url if you have push access'
      def sync
        DataMapper::Project.sync(options)
      end

      desc 'spec', 'Run specs for DM gems'
      def spec
        DataMapper::Project.spec(options)
      end

      desc 'release', 'Release all DM gems to rubygems'
      def release
        DataMapper::Project.release(options)
      end

      desc 'implode', 'Delete all DM gems'
      def implode
        if implode_confirmed?
          DataMapper::Project.implode(options)
        end
      end

      desc 'status', 'Show git status information'
      def status
        DataMapper::Project.status(options)
      end

      class Bundle < ::Thor

        namespace 'dm:bundle'

        include CommonOptions

        desc 'install', 'Bundle the DM repositories'
        def install
          DataMapper::Project.bundle_install(options)
        end

        desc 'update', 'Update the bundled DM repositories'
        def update
          DataMapper::Project.bundle_update(options)
        end

        desc 'show', 'Show the bundle content'
        def show
          DataMapper::Project.bundle_show(options)
        end

      end

      class Gem < ::Thor

        namespace 'dm:gem'

        include CommonOptions

        class_option :gemset, :type => :string, :aliases => '-g', :desc => 'The rvm gemset to install the gems to'

        desc 'install', 'Install all included gems into the specified rubies'
        def install
          DataMapper::Project.gem_install(options)
        end

        desc 'uninstall', 'Uninstall all included gems from the specified rubies'
        def uninstall
          DataMapper::Project.gem_uninstall(options)
        end

      end

      class Meta < ::Thor

        namespace 'dm:meta'

        desc 'list', 'List locally known DM repositories'
        def list
          DataMapper::Project.list
        end

      end

    private

      def implode_confirmed?
        return true if options[:pretend]
        question = "Are you really sure? This will destroy #{affected_repositories}! (yes)"
        ask(question) == 'yes'
      end

      def affected_repositories
        included = options[:include]
        if include_all?(included)
          'not only all repositories, but also everything below DM_DEV_BUNDLE_ROOT!'
        else
          "the following repositories: #{included.join(', ')}!"
        end
      end

      def include_all?(included)
        include_all_implicitly? || include_all_explicitly?
      end

      def include_all_implicitly?(included)
        included.nil?
      end

      def include_all_explicitly?(included)
        included.respond_to?(:each) && included.count == 1 && included.first == 'all'
      end
    end

  end
end

DM = DataMapper::Project

