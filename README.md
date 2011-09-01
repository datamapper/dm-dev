Setting up a DataMapper development environment
-----------------------------------------------

Contributing to DataMapper might seem intimidating at first. The variety
of available gems and github repositories might appear to be an
impenetrable jungle. Fear not! The following tasks help to simplify the
task of locally testing patches for DataMapper before submitting them.

The following steps will guide you through the process of fetching the
source and running the specs on multiple rubies (using rvm). The
provided tasks also make sure that you're always running the specs
against your local DataMapper source codes. This is very important once
you're working on a patch that affects multiple DataMapper gems.

Once you've verified your patch locally, submitted it, and had it accepted,
be sure to check the status of the [DataMapper CI server](http://ci.datamapper.org).
Check both the project that your patch is for, and all downstream projects.
(The console output from the spec run can be viewed by clicking the green/red
status icons on the build detail page, then clicking the 'Console Output' link
in the left-hand sidebar nav).

Prerequisites
-------------

You need to have [rvm](http://rvm.beginrescueend.com/), [bundler](https://github.com/carlhuda/bundler), [thor](https://github.com/wycats/thor), [ruby-github](https://rubygems.org/gems/ruby-github), [addressable](http://addressable.rubyforge.org/), [rest-client](http://rubygems.org/gems/rest-client) and [jeweler](https://github.com/technicalpickles/jeweler) available on your machine.

### Installing rvm

The awesome rvm comes as a gem and makes installing and using different
rubies a breeze. Be aware that the following commands may take quite
some time, depending on your machine.

    gem install rvm   # Please follow the instructions
    rvm install 1.8.7 # You should run specs on 1.8.7
    rvm install 1.9.2 # You should run specs on 1.9.2
    rvm install jruby # Bonus points for running on jruby
    rvm install rbx   # Bonus points for running on rbx

Reading through rvm's detailed [documentation](http://rvm.beginrescueend.com/)
is definitely time well spent too.

### Installing the required gems

Actually, it's enough to have the following gems installed in the rvm
ruby you use to run the dm-dev tasks. However, if you sometimes switch
rubies you might want to have the dm-dev tasks handy for all of them.

    rvm 1.8.7,1.9.2,jruby,rbx gem install jeweler bundler thor addressable ruby-github json rest-client

Once those are installed, you have all you need for the DataMapper thor tasks
to work.

Installing the DataMapper thor tasks
------------------------------------

The easiest way to install the thor tasks is to simply run the following.

    thor install https://github.com/datamapper/dm-dev/raw/master/tasks.rb

If you don't feel comfortable with executing code loaded from the
internet, you can also clone the github repo containing the tasks and
then install them like you would install any thor task.

    git clone git://github.com/datamapper/dm-dev.git
    thor install dm-dev/tasks.rb

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
    thor dm:bundle:force    # Force rebundling by removing all Gemfile.platform and Gemfile.platform.lock files
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

This means that once all dependencies are bundled for any given ruby, there's no need to clean anything between spec runs. Also, no re-bundling needs to happen before spec runs since everything is already bundled. Of course, the bundles can (and should) be updated manually from time to time, to ensure that the dependencies for the code under test are up to date.

The tasks make sure that you're always testing against local sources. This is very important if you're developing patches that touch multiple DM repositories. Testing against local sources only, will make sure that the code still works with all your modifications to potentially more than one DM repository.

To achieve this, the bundle task copies the Gemfile to `Gemfile.ruby_version` where *ruby_version* is any of the specified rubies to use. This is done because bundler automatically creates a `Gemfile.lock` after `bundle install`. In our case that leaves us with files like `Gemfile.1.9.2` and `Gemfile.1.9.2.lock`. That's necessary, because otherwise bundler confuses the the `BUNDLE_PATH` to use. Every command executed by the bundle tasks explicitly passes `BUNDLE_PATH=/path/to/DM_DEV_BUNDLE_ROOT/ruby_version` and `BUNDLE_GEMFILE=/path/to/Gemfile.ruby_version` as environment variables, to make sure that the right bundle is used.

## Remove all traces easily

Since the complete DM development environment is located in one single
folder, it's easy to get rid of it any time. Apart from obviously just
deleting the folder, you can use `thor dm:implode` just for the fun of
it.

When the `DM_DEV_INCLUDE` environment variable *is not specified*, all repositories will be deleted as well as the `DM_DEV_BUNDLE_ROOT`, meaning that you will have to re-bundle everything next time. (Be aware that this might take a long time!)

When the `DM_DEV_INCLUDE` environment variable *is specified*, only the
specified repositories will be deleted. The `DM_DEV_BUNDLE_ROOT` stays
untouched.

## Running specs

The spec task runs specs for all specified gems against all specified rubies and adapters. While running, it prints out a matrix, that shows for every ruby and every adapter if the specs `pass` or `fail`. The spec task makes sure that only local DM sources are used so you can safely assume that you're running the specs against your latest modifications.

Note that for the specs to reliably work, you should `thor dm:sync`
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

You can override user and password by setting the following ENV vars:

    export DM_DB_USER=your_db_user
    export DM_DB_PASSWORD=your_db_password

## The available thor tasks

    thor dm:bundle:force    # Force rebundling by removing all Gemfile.platform and Gemfile.platform.lock files
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

    DM_DEV_ROOT=/some/path                  # Points to where the DM sources will be installed and used
    DM_DEV_BUNDLE_ROOT=/some/path           # Points to where bundler will install all it's data
    DM_DEV_RUBIES="1.8.7 1.9.2"             # The rvm ruby interpreters to use
    DM_DEV_INCLUDE="dm-core dm-validations" # Makes sure that only these gems are used. When left out, all gems will be used
    DM_DEV_EXCLUDE="dm-tags dm-ar-finders"  # Makes sure that these gems are not used
    ADAPTERS="mysql postgres"               # Use only these DM adapters
    DM_DEV_GEMSET=datamapper                # With dm:gem:install, install all gems into the "datamapper" gemset
    VERBOSE=true                            # Print out every shell command before executing it
    BENCHMARK=true                          # Print the time the command took to execute

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

### Support passing options on to the underlying command

This is currently only supported for the `dm:spec` command where it can be
used to run any specific spec folder(s) or file(s).

The options can be passed by specifying them just like the underlying command
would expect them. To separate these options from the task's options themselves,
they need to be passed after a `--`.

Here's an example invocation:

    thor dm:spec -i dm-aggregates -R 1.8.7 1.9.2 -a sqlite -- spec/isolated

This would only run specs located in the `spec/isolated` folder. As
always, you can pass the `-v` switch to see the command that gets executed.

## Using private github clone URLs

If you have push access to any or all the DataMapper repositories, you
can pass the `--development` or `-d` switch to the `thor dm:sync`
command. This will use the private github clone URL and thus allow you
to push your changes back without manually having to edit the
`.git/config` file(s).

## Setting up a DataMapper development environment

All the `dm-dev` tasks rely on a common set of environment variables
that are used to determine a few things necessary for `dm-dev` to do its
thing.

    # You should probably set this! (defaults to Dir.pwd)
    # Every dm:* task assumes that sources are located in that directory.
    export DM_DEV_ROOT=/path/to/the/datamapper/sources

    # Those should have reasonable defaults but you can still tweak them
    export DM_DEV_BUNDLE_ROOT=/path/to/where/bundler/manages/dm/sources
    export DM_DEV_RUBIES="1.8.7 1.9.2 jruby rbx"
    export DM_DEV_GEMSET="datamapper"
    export DM_DEV_INCLUDE="some dm gems to include"
    export DM_DEV_EXCLUDE="some dm gems to exclude"

You can put those environment variable exports into your
`~/.bash_profile` for example.

Once you have the basics configured, `thor dm:sync` will clone all
DataMapper sources to `DM_DEV_ROOT`. With all sources synced, you're
ready to run specs for all the DataMapper gems. Running `thor dm:spec`
right away will perform a `thor dm:bundle:install` if it thinks that
this is still necessary. Obviously, you can also call `thor
dm:bundle:install` manually before running the specs.

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
      -i, [--include=one two three]    # The DM gems to include with this command (overwrites DM_DEV_INCLUDE)
      -r, [--root=ROOT]                # The directory where all DM source code is stored (overwrites DM_DEV_ROOT)
      -b, [--benchmark]                # Print the time the command took to execute
      -R, [--rubies=one two three]     # The rvm ruby interpreters to use with this command (overwrites DM_DEV_RUBIES)
      -p, [--pretend]                  # Print the shell commands that would get executed
      -B, [--bundle-root=BUNDLE_ROOT]  # The directory where bundler stores all its data (overwrites DM_DEV_BUNDLE_ROOT)
      -e, [--exclude=one two three]    # The DM gems to exclude with this command (overwrites DM_DEV_EXCLUDE)


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
    #   :rubies      => %w[ 1.8.7 1.9.2 jruby rbx ]                # overwrites ENV['DM_DEV_RUBIES']
    #   :include     => %w[ dm-core dm-validations ]               # overwrites ENV['DM_DEV_INCLUDE']
    #   :exclude     => %w[ dm-tags ]                              # overwrites ENV['DM_DEV_EXCLUDE']
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

## Adding new gems

You can instruct the thor tasks to take other gems into account too. All
you need to do is make sure that the cached repository configuration
contains entries for all the gems you want to test.

You can achieve this either by simply editing the
`#{DM_DEV_ROOT}/dm-dev.yml` file by hand, or by running the following
command:

    thor dm:meta:add -n your_gem_name -u https://github.com/you/and_your_gem

Subsequent operations will take the newly added gem into account,
given that it provides a `Gemfile` and a `rake spec` spec task.
