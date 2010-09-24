#!/usr/bin/env ruby -Ku
# encoding: utf-8

require 'set'
require 'fileutils'
require 'pathname'

require 'thor'
require 'addressable/uri'
require 'ruby-github'

class ::Project

  def self.command_names
    %w[ sync bundle:install bundle:update spec release implode]
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
        self.class.invoke :before, '#{command_name(name)}', env, repos
        @repos.each_with_index do |repo, index|
          @logger.next_command
          command_class('#{name}').new(repo, env, @logger, options[:verbose]).run
        end
        self.class.invoke :after, '#{command_name(name)}', env, repos
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
    @env      = environment_class.new(name)
    @root     = @env.root
    @repos    = Repositories.new(@root, name, @env.included, @env.excluded + excluded_repos)
    @logger   = Logger.new(@repos.count, @options[:verbose])
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
      @excluded_repos = excluded_repos
      @repositories   = fetch(repos).map do |repo|
        Repository.new(@root, repo)
      end
    end

    def each
      @repositories.each { |repo| yield(repo) }
    end

  private

    def fetch(repos)
      GitHub::API.user(@user).repositories.select do |repo|
        include?(repo, repos)
      end
    end

    def include?(repo, repos)
      if repos
        repos.include?(repo.name)
      else
        !@excluded_repos.include?(repo.name)
      end
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
    attr_reader :root
    attr_reader :included
    attr_reader :excluded
    attr_reader :rubies
    attr_reader :bundle_root

    def initialize(name)
      @name        = name
      @root        = Pathname(ENV['ROOT'       ] || Dir.pwd)
      @bundle_root = Pathname(ENV['BUNDLE_ROOT'] || @root.join(default_bundle_root))
      @included    = ENV['INCLUDE'] ? normalize(ENV['INCLUDE']) : default_included
      @excluded    = ENV['EXCLUDE'] ? normalize(ENV['EXCLUDE']) : default_excluded
      @rubies      = ENV['RUBIES' ] ? normalize(ENV['RUBIES' ]) : default_rubies
    end

    def default_bundle_root
      'BUNDLE_ROOT'
    end

    def default_included
      nil # means all
    end

    def default_excluded
      [] # overwrite in subclasses
    end

    def default_rubies
      %w[ 1.8.7 1.9.2 ]
    end

  private

    def normalize(string)
      string.gsub(',', ' ').split(' ')
    end

  end

  class Logger

    def initialize(repo_count, verbose)
      @total   = repo_count
      @padding = @total.to_s.length
      @index   = 0
      @verbose = verbose
    end

    def log(repo, action, command = nil, msg = nil)
      puts '[%0*d/%d] %s %s %s%s' % format(repo, action, command, msg)
    end

    def next_command
      @index += 1
    end

    def format(repo, action, command, msg)
      [ @padding, @index, @total, action, repo.name, msg, @verbose ? ": #{command}" : '' ]
    end

  end

  class Command

    attr_reader :repo
    attr_reader :env
    attr_reader :root
    attr_reader :path
    attr_reader :uri
    attr_reader :logger

    def initialize(repo, env, logger, verbose = false)
      @repo    = repo
      @env     = env
      @root    = @env.root
      @path    = @root.join(@repo.name)
      @uri     = @repo.uri
      @logger  = logger
      @verbose = verbose
    end

    def before
      # overwrite in subclasses
    end

    def after
      # overwrite in subclasses
    end

    def ignored?
      ignored_repos.include?(repo.name)
    end

    def ignored_repos
      [] # overwrite in subclasses
    end

    def working_dir
      path
    end

    def verbose?
      @verbose
    end

    def verbosity
      verbose? ? verbose : silent
    end

    def verbose
    end

    def silent
      '>& /dev/null'
    end

    def log(command = nil, msg = nil)
      logger.log(repo, action, command, msg)
    end

    class Sync < Command

      def self.new(repo, env, logger, verbose = false)
        return super unless self == Sync
        if env.root.join(repo.name).directory?
          Pull.new(repo, env, logger, verbose)
        else
          Clone.new(repo, env, logger, verbose)
        end
      end

      attr_reader :git_uri

      def initialize(repo, env, logger, verbose = false)
        super
        @git_uri = uri.dup
        @git_uri.scheme = scheme
      end

      def run
        FileUtils.cd(working_dir) do
          before
          log(command); system(command)
          after
        end
      end

      def scheme
        'git'
      end

      class Clone < Sync

        def command
          "git clone #{git_uri}.git #{verbosity}"
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

      def initialize(repo, env, logger, verbose = false)
        super
        @rubies = env.rubies
      end

      def run
        FileUtils.cd(working_dir) do
          rubies.each do |ruby|
            before
            yield(ruby)
            after
          end
        end
      end

      def command(ruby)
        "rvm #{ruby} exec bash -c"
      end

      def action(ruby = nil)
        "[#{ruby}]"
      end

    end

    class Bundle < Rvm

      class Install < Bundle

        def bundle_command
          'install'
        end

        def action(ruby = nil)
          "#{super} bundle install"
        end

      end

      class Update < Bundle

        def bundle_command
          'update'
        end

        def action(ruby = nil)
          "#{super} bundle update"
        end

      end

      def initialize(repo, env, logger, verbose = false)
        super
        @bundle_root = env.bundle_root
        rubies.each { |ruby| bundle_path(ruby).mkpath }
      end

      def run
        super do |ruby|
          if block_given?
            yield ruby
          else
            if executable?
              sleep timeout
              log ruby, command(ruby)
              make_gemfile(ruby)
              system command(ruby)
            else
              log ruby, command(ruby), "SKIPPED - #{explanation}"
            end
          end
        end
      end

      def executable?
        !ignored? && repo.installable?
      end

      def command(ruby)
        "#{super} \"#{environment(ruby)} bundle #{bundle_command} #{options} #{verbosity}\""
      end

      def environment(ruby)
        "BUNDLE_PATH='#{bundle_path(ruby)}' BUNDLE_GEMFILE='#{gemfile(ruby)}'"
      end

      def bundle_path(ruby)
        @bundle_root.join(ruby)
      end

      def gemfile(ruby)
        "Gemfile.#{ruby}"
      end

      def make_gemfile(ruby)
        gemfile = working_dir.join(gemfile(ruby))
        unless gemfile.file?
          FileUtils.cp(working_dir.join('Gemfile.local'), working_dir.join(gemfile(ruby)))
        end
      end

      def options
        nil
      end

      def timeout
        0
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

      def log(ruby = nil, command = nil, msg = nil)
        logger.log(repo, action(ruby), command, msg)
      end

    end

    class Spec < Bundle

      def initialize(repo, env, logger, verbose = false)
        super
      end

      def run

        puts "\nh2. %s\n\n" % repo.name
        puts '| RUBY  | %s |' % env.adapters.join(' | ')

        super do |ruby|

          print '| %s |' % ruby

          if block_given?
            yield ruby
          else
            log    command(ruby)
            system command(ruby)

            print ' %s |' % [ $?.success? ? 'pass' : 'fail' ]
          end

          puts

        end

      end

      def environment(ruby)
        "#{super} TZ='utc'"
      end

      def bundle_command
        'exec rake spec'
      end

      def action(ruby = nil)
        "#{super} Testing"
      end

    end

    class Release < Command

      def run
        # TODO move to its own command
        clean_repository(project_name)

        FileUtils.cd(working_dir) do
          log(command)
          system(command)
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
        system command
      end

      def command
        "rm -rf #{repo.name} #{verbosity}"
      end

      def action
        'Deleting'
      end

    end

  end

end

module DataMapper

  class Project < ::Project

    def initialize(options = {})
      super
      commands['bundle:install'] = DataMapper::Project::Bundle::Install
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
      FileUtils.rm_rf env.bundle_root if env.included.nil?
    end

    class Environment < ::Project::Environment

      attr_reader :adapters

      def initialize(name)
        super
        @adapters ||= ENV['ADAPTERS'] ? normalize(ENV['ADAPTERS']) : default_adapters
      end

      def default_adapters
        %w[ in_memory yaml sqlite postgres mysql ]
      end

      def default_excluded
        %w[ dm-oracle-adapter dm-sqlserver-adapter ]
      end

    end

    module Bundle

      def support_lib(ruby)
        ruby == '1.8.6' ? 'EXTLIB="true"' : ''
      end

      def adapters(ruby)
        env.adapters.join(',')
      end

      def gemfile(ruby)
        "#{super}#{local_install? ? '.local' : ''}"
      end

      def ignored_repos
        %w[ dm-dev data_mapper datamapper.github.com dm-ferret-adapter rails_datamapper ]
      end

      def timeout
        2
      end

      class Install < ::Project::Command::Bundle::Install

        include DataMapper::Project::Bundle

        def environment(ruby)
          "#{super} #{support_lib(ruby)} ADAPTERS='#{adapters(ruby)}'"
        end

        def before
          @local_install = system "rake local_gemfile #{verbosity}"
        end

        def local_install?
          @local_install
        end

      end

    end

    class Spec < ::Project::Command::Spec

      include DataMapper::Project::Bundle

      def run
        super do |ruby|
          env.adapters.each do |adapter|

            @adapter = adapter # HACK?

            log    command(ruby) if verbose?
            system command(ruby)

            print ' %s |' % [ $?.success? ? 'pass' : 'fail' ]
          end
        end
      end

      def environment(ruby)
        "#{super} #{support_lib(ruby)} ADAPTER='#{@adapter}'"
      end

      def local_install?
        working_dir.join('Gemfile.local').file?
      end

    end

    # The tasks
    class Tasks < ::Thor

      namespace :dm

      class_option :verbose, :default => false, :aliases => '-v'

      desc 'sync', 'Sync with the DM repositories'
      def sync
        DataMapper::Project.sync(options)
      end

      desc 'bundle', 'Bundle the DM repositories'
      def bundle
        DataMapper::Project.bundle(options)
      end

      desc 'spec', 'Run specs for DM gems'
      def spec
        DataMapper::Project.spec(options)
      end

      desc 'release', 'Release all DM gems to rubygems'
      def release
        DataMapper::Project.release(options)
      end

    end

  end
end

DM = DataMapper::Project
