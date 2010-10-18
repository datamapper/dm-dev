Setting up a DataMapper development environment
-----------------------------------------------

Contributing to DataMapper might seem intimidating at first. The variety
of available gems and github repositories might appear to be an
impenetrable jungle. Fear not! The following tasks actually make it
pretty easy to solidly test any kind of patch for DataMapper.

The following steps will guide you through the process of fetching the
source and running the specs on multiple rubies (using rvm). The
provided tasks also make sure that you're always running the specs
against your local DataMapper source codes. This is very important once
you're working on a patch that affects multiple DataMapper gems.

Prerequisites
-------------

You need to have [rvm](http://rvm.beginrescueend.com/), [bundler](http://github.com/carlhuda/bundler), [thor](http://github.com/wycats/thor), [ruby-github](https://rubygems.org/gems/ruby-github), [addressable](http://addressable.rubyforge.org/) and [jeweler](http://github.com/technicalpickles/jeweler) available on your machine.

### Installing rvm

The awesome rvm comes as a gem and makes installing and using different
rubies a breeze. Be aware that the following commands may take quite
some time, depending on your machine.

    gem install rvm   # Please follow the instructions
    rvm install 1.8.7 # You need to run specs on 1.8.7
    rvm install 1.9.2 # You need to run specs on 1.9.2
    rvm install jruby # Bonus points for running on jruby
    rvm install rbx   # Bonus points for running on rbx

Reading through rvm's detailed [documentation](http://rvm.beginrescueend.com/)
is definitely time well spent too.

Currently, you need to manually make sure that jeweler is installed into any of the rubies you plan to use. This is because the DataMapper rake tasks depend on jeweler and we have to invoke them *before* we can enter a bundled environment.

To install jeweler into multiple rubies, run the following command

    rvm 1.8.7,1.9.2,jruby,rbx gem install jeweler

In the future, there might be a task that will handle this
transparently.

### Installing the required gems

    gem install bundler thor addressable ruby-github

Once those are installed, you have all you need for the DataMapper thor tasks
to work.

Installing the DataMapper thor tasks
------------------------------------

The easiest way to install the thor tasks is to simply run the following.

    thor install http://github.com/datamapper/dm-dev/raw/master/tasks.rb

If you don't feel comfortable with executing code loaded from the
internet, you can also clone the github repo containing the tasks and
then install them like you would install any thor task.

    git clone git://github.com/datamapper/dm-dev.git
    cd dm-dev
    thor install tasks.rb

Either way, after showing you the content of tasks.rb, thor will ask you for a
name for those new tasks.

    Please specify a name for tasks.rb in the system repository [tasks.rb]:

You can choose any name at that prompt, or you can just hit enter to
accept the default. All provided thor tasks are available below the `dm`
namespace.

Verify the installation by printing a list of available thor tasks to
your screen.

    ree-1.8.7-2010.02@datamapper mungo:dm-dev snusnu$ thor -T
    dm
    --
    thor dm:bundle:install  # Bundle the DM repositories
    thor dm:bundle:show     # Show the bundle content
    thor dm:bundle:update   # Update the bundled DM repositories
    thor dm:gem:install     # Install all included gems into the specified rubies
    thor dm:gem:uninstall   # Uninstall all included gems from the specified rubies
    thor dm:implode         # Delete all DM gems
    thor dm:meta:list       # List locally known DM repositories
    thor dm:release         # Release all DM gems to rubygems
    thor dm:spec            # Run specs for DM gems
    thor dm:status          # Show git status information
    thor dm:sync            # Sync with the DM repositories

If everything went fine, you should see the above list of available
commands (among any other thor tasks you might have installed already).

## dm-dev

The following describes the new DM development tasks and shows how you can use them. These tasks greatly simplify the management of DM related source code and hopefully also help interested contributors to get a fully functional DM development up and running fast. By invoking very few commands, contributors can verify if their patch(es) meet the DM quality guidelines, aka, do specs pass on all supported platforms?

## Totally isolated

The following tasks don't affect the system gems *at all*. Nor do they mess with any rvm ruby specific (system)gem(set). By default, *everything* will be bundled below `"#{Dir.pwd}/DM_DEV_BUNDLE_ROOT"`, you can alter the install location by passing the `DM_DEV_BUNDLE_ROOT=/path/to/bundle/root` ENV var. `DM_DEV_BUNDLE_ROOT` contains separate folders for every ruby in use.

This means that once all dependencies are bundled for any given ruby, there's no need to clean anything between spec runs. Also, no re-bundling needs to happen before spec runs since everything is already bundled. Of course, the bundles can be updated manually, to ensure that the code under test is up to date. In the near future, a command that tells you exactly which repos need updating, will be included.

The tasks make sure that you're always testing against local sources. This is very important if you're developing patches that touch multiple DM repositories. Testing against local sources only, will make sure that the code still works with all your modifications to potentially more than one DM repository.

To achieve this, the bundle tasks first create a `Gemfile.local` for every repository that includes a Gemfile (or isn't otherwise ignored), and then copies that file to `Gemfile.ruby_version.local` where *ruby_version* is any of the specified rubies to use. This is done because bundler automatically creates a `Gemfile.lock` after `bundle install`. In our case that leaves us with files like `Gemfile.1.9.2.local` and `Gemfile.1.9.2.local.lock`. That's necessary, because otherwise bundler confuses the the `BUNDLE_PATH` to use. Every command executed by the bundle tasks explicitly passes `BUNDLE_PATH=/path/to/DM_DEV_BUNDLE_ROOT/ruby_version` and `BUNDLE_GEMFILE=/path/to/Gemfile.ruby_version.local` as environment variables, to make sure that the right (local) bundle is used.

## Remove all traces easily

Since the complete DM development environment is located in one single
folder, it's easy to get rid of it any time. Apart from obviously just
deleting the folder, you can use `thor dm:implode` just for the fun of
it.

When the `INCLUDE` environment variable *is not specified*, all repositories will be deleted as well as the `DM_DEV_BUNDLE_ROOT`, meaning that you will have to re-bundle everything next time.

When the `INCLUDE` environment variable *is specified*, only the
specified repositories will be deleted. The `DM_DEV_BUNDLE_ROOT` stays
untouched.

## Running specs

The spec task uses the bundled DM sources to run the specs for all specified gems against all specified rubies and adapters. While running, it prints out a matrix, that shows for every ruby and every adapter if the specs `pass` or `fail`.

Note that for the specs to reliably work, you should sync
*all* DM repositories once. This is necessary because some gems might
depend on other DM gems and since we're running all specs with local
code, we need to make sure that this code is available.

Also note that for the DataMapper tests to run, you need to have two
databases setup on all the adapters you want to test. The names for
these databases are:

    datamapper_default_tests
    datamapper_alternate_tests

The specs will connect to these databases using the `datamapper` user
with password `datamapper`. Be sure to grant enough privileges to these
users, on the above mentioned databases.

## The available thor tasks

    thor dm:bundle:install  # Bundle the DM repositories
    thor dm:bundle:show     # Show the bundle content
    thor dm:bundle:update   # Update the bundled DM repositories
    thor dm:gem:install     # Install all included gems into the specified rubies
    thor dm:gem:uninstall   # Uninstall all included gems from the specified rubies
    thor dm:implode         # Delete all DM gems
    thor dm:meta:list       # List locally known DM repositories
    thor dm:release         # Release all DM gems to rubygems
    thor dm:spec            # Run specs for DM gems
    thor dm:status          # Show git status information
    thor dm:sync            # Sync with the DM repositories

## Common options

Every task can be configured with a few environment variables.

    DM_DEV_ROOT=/some/path           # Points to where the DM sources will be installed and used
    DM_DEV_BUNDLE_ROOT=/some/path    # Points to where bundler will install all it's data
    RUBIES="1.8.7 1.9.2"             # The rvm ruby interpreters to use
    INCLUDE="dm-core dm-validations" # Makes sure that only these gems are used. When left out, all gems will be used
    EXCLUDE="dm-tags dm-ar-finders"  # Makes sure that these gems are not used
    ADAPTERS="mysql postgres"        # Use only these DM adapters
    VERBOSE=true                     # Print out every shell command before executing it

Any of these environment variables has an equivalent thor option as will be
seen below. When a thor option is passed for which the respective
environment variable has already been set too, the thor option will
overwrite the environment variable's value. The same goes for using the
Ruby API directly. Any of the passed in options (a Hash) overwrites any
setting already configured via the environment variables.

## Task specific options

The `dm:gem:install`, `dm:gem:uninstall` and `dm:sync` tasks accept
additional options to further configure their behavior. Both
`dm:gem:install` and `dm:gem:uninstall` accept the `--gemset` or `-g`
option that allows you to pass the name of the _rvm gemset_ you want to
install or uninstall the gems to or from. If left out, the respective
_global rvm gemsets_ will be used. Have a look at the section below for
an explanation of `dm:sync`'s `--development` or `-d` option.

## Using private github clone URLs

If you have push access to any or all the DataMapper repositories, you
can pass the `--development` or `-d` switch to the `thor dm:sync`
command. This will use the private github clone URL and thus allow you
to push your changes back without manually having to edit the
`.git/config` file(s).

## Know what's going on

Every task supports the `-p` or `--pretend` switch. When passed,
no command will actually get executed. Instead, the commands to
execute are printed to the console. Executing these commands in your
shell manually, has the same effect as running the thor task itself.

This is interesting if you want to get familiar with how dm-dev does
it's thing, or if you want to run the commands directly, without the
thor tasks involved.

All the tasks also accept the `-v` or `--verbose` switch. When passed,
output from any commands won't be suppressed, thus allowing you to see
what the various commands actually return.

Note that passing `-v` or `--verbose` in addition to `-p` or `--pretend`
will remove the ouput silencing from the commands. This means that when
executing them, you can watch command output as it arrives.

Here's an example of what gets printed for the typical commands.
Obviously your results may differ.

    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:sync -i dm-validations -p -v
    <GitHub::User name="DataMapper">
    cd /Users/snusnu/projects/github/shared/datamapper/dm-dev/dm-validations
    git checkout master ; git pull --rebase

    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:bundle:install -i dm-validations -p -v
    <GitHub::User name="DataMapper">
    cd /Users/snusnu/projects/github/shared/datamapper/dm-dev/dm-validations
    rvm 1.8.7 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.8.7' BUNDLE_GEMFILE='Gemfile.1.8.7.local' ADAPTERS='in_memory yaml sqlite postgres mysql' bundle install --without quality "
    rvm 1.9.2 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.9.2' BUNDLE_GEMFILE='Gemfile.1.9.2.local' ADAPTERS='in_memory yaml sqlite postgres mysql' bundle install --without quality "
    rvm jruby exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/jruby' BUNDLE_GEMFILE='Gemfile.jruby.local' ADAPTERS='in_memory yaml sqlite postgres mysql' bundle install --without quality "
    rvm rbx exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/rbx' BUNDLE_GEMFILE='Gemfile.rbx.local' ADAPTERS='in_memory yaml sqlite postgres mysql' bundle install --without quality "

    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:spec -i dm-validations -p -v
    <GitHub::User name="DataMapper">
    cd /Users/snusnu/projects/github/shared/datamapper/dm-dev/dm-validations
    rvm 1.8.7 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.8.7' BUNDLE_GEMFILE='Gemfile.1.8.7.local' ADAPTER=in_memory TZ=utc bundle exec rake spec "
    rvm 1.8.7 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.8.7' BUNDLE_GEMFILE='Gemfile.1.8.7.local' ADAPTER=yaml TZ=utc bundle exec rake spec "
    rvm 1.8.7 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.8.7' BUNDLE_GEMFILE='Gemfile.1.8.7.local' ADAPTER=sqlite TZ=utc bundle exec rake spec "
    rvm 1.8.7 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.8.7' BUNDLE_GEMFILE='Gemfile.1.8.7.local' ADAPTER=postgres TZ=utc bundle exec rake spec "
    rvm 1.8.7 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.8.7' BUNDLE_GEMFILE='Gemfile.1.8.7.local' ADAPTER=mysql TZ=utc bundle exec rake spec "
    rvm 1.9.2 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.9.2' BUNDLE_GEMFILE='Gemfile.1.9.2.local' ADAPTER=in_memory TZ=utc bundle exec rake spec "
    rvm 1.9.2 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.9.2' BUNDLE_GEMFILE='Gemfile.1.9.2.local' ADAPTER=yaml TZ=utc bundle exec rake spec "
    rvm 1.9.2 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.9.2' BUNDLE_GEMFILE='Gemfile.1.9.2.local' ADAPTER=sqlite TZ=utc bundle exec rake spec "
    rvm 1.9.2 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.9.2' BUNDLE_GEMFILE='Gemfile.1.9.2.local' ADAPTER=postgres TZ=utc bundle exec rake spec "
    rvm 1.9.2 exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/1.9.2' BUNDLE_GEMFILE='Gemfile.1.9.2.local' ADAPTER=mysql TZ=utc bundle exec rake spec "
    rvm jruby exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/jruby' BUNDLE_GEMFILE='Gemfile.jruby.local' ADAPTER=in_memory TZ=utc bundle exec rake spec "
    rvm jruby exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/jruby' BUNDLE_GEMFILE='Gemfile.jruby.local' ADAPTER=yaml TZ=utc bundle exec rake spec "
    rvm jruby exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/jruby' BUNDLE_GEMFILE='Gemfile.jruby.local' ADAPTER=sqlite TZ=utc bundle exec rake spec "
    rvm jruby exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/jruby' BUNDLE_GEMFILE='Gemfile.jruby.local' ADAPTER=postgres TZ=utc bundle exec rake spec "
    rvm jruby exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/jruby' BUNDLE_GEMFILE='Gemfile.jruby.local' ADAPTER=mysql TZ=utc bundle exec rake spec "
    rvm rbx exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/rbx' BUNDLE_GEMFILE='Gemfile.rbx.local' ADAPTER=in_memory TZ=utc bundle exec rake spec "
    rvm rbx exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/rbx' BUNDLE_GEMFILE='Gemfile.rbx.local' ADAPTER=yaml TZ=utc bundle exec rake spec "
    rvm rbx exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/rbx' BUNDLE_GEMFILE='Gemfile.rbx.local' ADAPTER=sqlite TZ=utc bundle exec rake spec "
    rvm rbx exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/rbx' BUNDLE_GEMFILE='Gemfile.rbx.local' ADAPTER=postgres TZ=utc bundle exec rake spec "
    rvm rbx exec bash -c "BUNDLE_PATH='/Users/snusnu/projects/github/shared/datamapper/dm-dev/DM_DEV_BUNDLE_ROOT/rbx' BUNDLE_GEMFILE='Gemfile.rbx.local' ADAPTER=mysql TZ=utc bundle exec rake spec "

## Example thor session

    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor help dm
    Tasks:
      /path/to/thor dm:bundle:install  # Bundle the DM repositories
      /path/to/thor dm:bundle:show     # Show the bundle content
      /path/to/thor dm:bundle:update   # Update the bundled DM repositories
      /path/to/thor dm:implode         # Delete all DM gems
      /path/to/thor dm:meta:list       # List locally known DM repositories
      /path/to/thor dm:release         # Release all DM gems to rubygems
      /path/to/thor dm:spec            # Run specs for DM gems
      /path/to/thor dm:status          # Show git status information
      /path/to/thor dm:sync            # Sync with the DM repositories

    Options:
      -v, [--verbose]                  # Print the shell commands being executed
      -a, [--adapters=one two three]   # The DM adapters to use with this command (overwrites ADAPTERS)
      -i, [--include=one two three]    # The DM gems to include with this command (overwrites INCLUDE)
      -r, [--root=ROOT]                # The directory where all DM source code is stored (overwrites DM_DEV_ROOT)
      -b, [--benchmark]                # Print the time the command took to execute
      -R, [--rubies=one two three]     # The rvm ruby interpreters to use with this command (overwrites RUBIES)
      -p, [--pretend]                  # Print the shell commands that would get executed
      -B, [--bundle-root=BUNDLE_ROOT]  # The directory where bundler stores all its data (overwrites DM_DEV_BUNDLE_ROOT)
      -e, [--exclude=one two three]    # The DM gems to exclude with this command (overwrites EXCLUDE)


    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:sync -i dm-validations dm-constraints
    <GitHub::User name="DataMapper">
    [1/2] Cloning dm-constraints
    [2/2] Cloning dm-validations
    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:sync -i dm-validations dm-constraints
    <GitHub::User name="DataMapper">
    [1/2] Pulling dm-constraints
    [2/2] Pulling dm-validations
    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:implode -i dm-validations dm-constraints
    <GitHub::User name="DataMapper">
    [1/2] Deleting dm-constraints
    [2/2] Deleting dm-validations
    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:sync -i dm-validations dm-constraints
    <GitHub::User name="DataMapper">
    [1/2] Cloning dm-constraints
    [2/2] Cloning dm-validations
    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:bundle:install -R 1.8.7 1.9.2 jruby rbx -i dm-validations dm-constraints
    <GitHub::User name="DataMapper">
    [1/2] [1.8.7] bundle install dm-constraints
    [1/2] [1.9.2] bundle install dm-constraints
    [1/2] [jruby] bundle install dm-constraints
    [1/2] [rbx] bundle install dm-constraints
    [2/2] [1.8.7] bundle install dm-validations
    [2/2] [1.9.2] bundle install dm-validations
    [2/2] [jruby] bundle install dm-validations
    [2/2] [rbx] bundle install dm-validations
    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:bundle:update -R 1.8.7 1.9.2 jruby rbx -i dm-validations dm-constraints
    <GitHub::User name="DataMapper">
    [1/2] [1.8.7] bundle update dm-constraints
    [1/2] [1.9.2] bundle update dm-constraints
    [1/2] [jruby] bundle update dm-constraints
    [1/2] [rbx] bundle update dm-constraints
    [2/2] [1.8.7] bundle update dm-validations
    [2/2] [1.9.2] bundle update dm-validations
    [2/2] [jruby] bundle update dm-validations
    [2/2] [rbx] bundle update dm-validations
    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ thor dm:spec -R 1.8.7 1.9.2 jruby rbx -i dm-validations dm-constraints
    <GitHub::User name="DataMapper">

    h2. dm-constraints

    | RUBY  | in_memory | yaml | sqlite | postgres | mysql |
    | 1.8.7 | pass | pass | pass | pass | pass |
    | 1.9.2 | pass | pass | pass | pass | pass |
    | jruby | pass | pass | pass | pass | pass |
    | rbx | pass | pass | pass | pass | pass |

    h2. dm-validations

    | RUBY  | in_memory | yaml | sqlite | postgres | mysql |
    | 1.8.7 | pass | pass | pass | pass | pass |
    | 1.9.2 | pass | pass | pass | pass | pass |
    | jruby | pass | pass | pass | pass | pass |
    | rbx | pass | pass | pass | pass | pass |

## Using the thor tasks inside the source directories

When inside any DM repo directory, leaving out a directory to include means
the task will only operate on the repo residing in the current working
directory. If you want to overwrite that behavior, specify `-i all` explicitly.

This means that when you're working on a gem, you can simply `cd` into
that directory, and then run any of the tasks without explicitly
providing the `-i` option to scope the task to only some gem(s).

Example:

    export DM_DEV_ROOT=/path/to/dm/dev/root
    cd $DM_DEV_ROOT/dm-validations

    thor dm:sync           # same as passing: -i dm-validations
    thor dm:list           # same as passing: -i dm-validations
    thor dm:bundle:install # same as passing: -i dm-validations
    thor dm:bundle:update  # same as passing: -i dm-validations
    thor dm:bundle:show    # same as passing: -i dm-validations
    thor dm:spec           # same as passing: -i dm-validations
    thor dm:implode        # same as passing: -i dm-validations

All the above commands will *only* use dm-validations. Of course you can
still pass any other additional options to the commands.

## The available ruby API

    # All the methods below accept the following options.
    #
    #   :root        => "/path/to/store/dm/sources"                # overwrites ENV['DM_DEV_ROOT']
    #   :bundle_root => "/path/to/store/dm/bundler/data"           # overwrites ENV['DM_DEV_BUNDLE_ROOT']
    #   :rubies      => %w[ 1.8.7 1.9.2 jruby rbx ]                # overwrites ENV['RUBIES']
    #   :include     => %w[ dm-core dm-validations ]               # overwrites ENV['INCLUDE']
    #   :exclude     => %w[ dm-tags ]                              # overwrites ENV['EXCLUDE']
    #   :adapters    => %w[ in_memory yaml sqlite mysql postgres ] # overwrites ENV['ADAPTERS']
    #   :verbose     => false                                      # overwrites ENV['VERBOSE']
    #   :benchmark   => false
    #

    DM.sync
    DM.list
    DM.bundle_install
    DM.bundle_update
    DM.bundle_show
    DM.spec
    DM.implode

## Example IRB session

The following IRB session demonstrate a typical workflow. The API used in this session can also be invoked via system wide thor tasks.

    ree-1.8.7-2010.02 mungo:dm-dev snusnu$ irb -r tasks.rb
    ree-1.8.7-2010.02 > DM.sync :include => %w[ dm-validations dm-constraints ]
    <GitHub::User name="DataMapper">
    [1/2] Cloning dm-constraints
    [2/2] Cloning dm-validations
     => nil
    ree-1.8.7-2010.02 > DM.sync :include => %w[ dm-validations dm-constraints ]
    <GitHub::User name="DataMapper">
    [1/2] Pulling dm-constraints
    [2/2] Pulling dm-validations
     => nil
    ree-1.8.7-2010.02 > DM.implode :include => %w[ dm-validations dm-constraints ]
    <GitHub::User name="DataMapper">
    [1/2] Deleting dm-constraints
    [2/2] Deleting dm-validations
     => nil
    ree-1.8.7-2010.02 > DM.sync :include => %w[ dm-validations dm-constraints ]
    <GitHub::User name="DataMapper">
    [1/2] Cloning dm-constraints
    [2/2] Cloning dm-validations
     => nil
    ree-1.8.7-2010.02 > DM.bundle_install :rubies => %w[ 1.8.7 1.9.2 jruby rbx], :include => %w[ dm-validations dm-constraints ]
    <GitHub::User name="DataMapper">
    [1/2] [1.8.7] bundle install dm-constraints
    [1/2] [1.9.2] bundle install dm-constraints
    [1/2] [jruby] bundle install dm-constraints
    [1/2] [rbx] bundle install dm-constraints
    [2/2] [1.8.7] bundle install dm-validations
    [2/2] [1.9.2] bundle install dm-validations
    [2/2] [jruby] bundle install dm-validations
    [2/2] [rbx] bundle install dm-validations
     => nil
    ree-1.8.7-2010.02 > DM.bundle_update :rubies => %w[ 1.8.7 1.9.2 jruby rbx], :include => %w[ dm-validations dm-constraints ]
    <GitHub::User name="DataMapper">
    [1/2] [1.8.7] bundle update dm-constraints
    [1/2] [1.9.2] bundle update dm-constraints
    [1/2] [jruby] bundle update dm-constraints
    [1/2] [rbx] bundle update dm-constraints
    [2/2] [1.8.7] bundle update dm-validations
    [2/2] [1.9.2] bundle update dm-validations
    [2/2] [jruby] bundle update dm-validations
    [2/2] [rbx] bundle update dm-validations
     => nil
    ree-1.8.7-2010.02 > DM.spec :rubies => %w[ 1.8.7 1.9.2 jruby rbx], :include => %w[ dm-validations dm-constraints ]
    <GitHub::User name="DataMapper">

    h2. dm-constraints

    | RUBY  | in_memory | yaml | sqlite | postgres | mysql |
    | 1.8.7 | pass | pass | pass | pass | pass |
    | 1.9.2 | pass | pass | pass | pass | pass |
    | jruby | pass | pass | pass | pass | pass |
    | rbx | pass | pass | pass | pass | pass |

    h2. dm-validations

    | RUBY  | in_memory | yaml | sqlite | postgres | mysql |
    | 1.8.7 | pass | pass | pass | pass | pass |
    | 1.9.2 | pass | pass | pass | pass | pass |
    | jruby | pass | pass | pass | pass | pass |
    | rbx | pass | pass | pass | pass | pass |
     => nil


