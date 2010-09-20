#!/usr/bin/env ruby -Ku

# encoding: utf-8

require 'fileutils'
require 'pathname'
require 'thor'
require 'addressable/uri'
require 'ruby-github'  # TODO: replace ruby-github with something better maintained

RUBY_VERSIONS = %w[ 1.8.6 1.8.7 1.9.1 1.9.2-head rbx ]
ADAPTERS      = %w[ in_memory yaml sqlite postgres mysql ]
DM_ROOT       = ENV['DM_ROOT'] || Dir.pwd

class Dm < Thor

  desc 'sync', 'Sync with the DM repositories'
  method_options :scheme => 'git'
  def sync
    create_path
    sync_repositories
  end

  desc 'spec', 'Run specs for DM gems'
  def spec
    installable.each do |repository|
      repository_name = repository.name

      puts "\nh2. %s\n\n" % repository_name
      puts '|| %s |' % ADAPTERS.join(' | ')

      FileUtils.cd(project_directory(repository_name)) do
        RUBY_VERSIONS.each do |ruby_version|
          print '| %s |' % ruby_version

          clean_repository('do')
          clean_repository(repository_name)

          system <<-CMD
            rake local_gemfile >& /dev/null
            #{ruby_version == '1.8.6' ? 'EXTLIB="true"' : ''} TZ="utc" ADAPTER="#{ADAPTERS.join(',')}" BUNDLE_GEMFILE="Gemfile.local" rvm #{ruby_version}, -S bundle install --without=quality --relock >& /dev/null
          CMD

          ADAPTERS.each do |adapter|
            system <<-CMD
              #{ruby_version == '1.8.6' ? 'EXTLIB="true"' : ''} TZ="utc" ADAPTER="#{adapter}" BUNDLE_GEMFILE="Gemfile.local" rvm #{ruby_version}, -S bundle exec rake spec >& /dev/null
            CMD

            print ' %s |' % [ $?.success? ? 'pass' : 'fail' ]
          end

          puts
        end
      end
    end
  end

  desc 'release', 'Release all DM gems to rubygems'
  def release
    installable.each do |repository|
      project_name = repository.name

      puts "Cleaning #{project_name}"
      clean_repository(project_name)

      FileUtils.cd(project_directory(project_name)) do
        system <<-CMD
          rake release
        CMD
      end
    end
  end

private

  def path
    @path ||= Pathname(DM_ROOT).expand_path
  end

  def repositories
    @repositories ||= GitHub::API.user('datamapper').repositories.reject do |repository|
      %w[ dm-more ].include?(repository.name)
    end
  end

  def installable
    @installable ||= repositories.select do |repository|
      project_directory(repository.name).join('Gemfile').file? ||
      %w[ data_mapper ].include?(repository.name)
    end
  end

  def scheme
    @scheme ||= options[:scheme]
  end

  def create_path
    path.mkpath
  end

  def sync_repositories
    total   = repositories.size
    padding = total.to_s.length

    repositories.each_with_index do |repository, index|
      puts '[%0*d/%d] Syncing %s' % [ padding, index + 1, total, repository.name ]

      uri           = repository_uri(repository)
      command, path = git_command(uri)

      FileUtils.cd(path) { system(command) }
    end
  end

  def repository_uri(repository)
    uri = Addressable::URI.parse(repository.url)
    uri.scheme = scheme
    uri
  end

  def git_command(uri)
    project_directory = project_directory(uri.basename)

    if project_directory.directory?
      [ 'git checkout master >& /dev/null; git pull --rebase >& /dev/null', project_directory ]
    else
      [ "git clone #{uri}.git >& /dev/null;", path ]
    end
  end

  def project_directory(name)
    path.join(name)
  end

  def clean_repository(project_name)
    FileUtils.cd(project_directory(project_name)) { system 'git clean -dfX --quiet' }
  end

end

