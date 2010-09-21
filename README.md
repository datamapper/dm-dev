WARNING: This is currently not working
======================================

The tasks are currently still a bit broken, we're working hard on it!

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

You need a few things before you can start working on DataMapper itself.
Namely [rvm](http://rvm.beginrescueend.com/) and
[thor](http://github.com/wycats/thor). Once you have those, you need to
install the thor tasks and you're ready to go.

Installing rvm
--------------

The awesome rvm comes as a gem and makes installing and using different
rubies a breeze. Be aware that the following commands may take quite
some time, depending on your machine.

    gem install rvm   # Please follow the instructions
    rvm install 1.8.7 # You need to run specs on 1.8.7
    rvm install 1.9.2 # You need to run specs on 1.9.2
    rvm install jruby # Bonus points for running on jruby
    rvm install rbx   # Bonus points for running on rbx

Reading through rvm's detailed [documentation]((http://rvm.beginrescueend.com/)
is definitely time well spent too.

Installing thor and the DataMapper tasks
----------------------------------------

Thor is yet another rubygem, providing a nice framework for writing
system wide thor tasks or ruby executables. Install it like you would
with any other rubygem, then clone the DataMapper tasks and install them
systemwide.

    gem install thor
    git clone git://github.com/datamapper/dm-dev.git
    cd dm-dev
    thor install dev_tasks.rb

After showing you the content of dev_tasks.rb, thor will ask you for a
namespace for those new tasks.

    Please specify a name for dev_tasks.rb in the system repository [dev_tasks.rb]:

You can choose any name at that prompt, or you can just hit enter to
accept the default. The provided thor tasks explicitly define their
namespace to be 'dm'.

The available thor tasks
---------------------------

Once you have the thor tasks available on your machine, you can pull
down the DataMapper sources, update them and run the specs using an rvm
setup. The following taks are currently available:

    thor dm:sync     # syncs all datamapper repos to DM_ROOT (or Dir.pwd)
    thor dm:spec     # runs specs on all RUBY_VERSIONS
    thor dm:release  # release all datamapper gems to rubygems

Developing a patch for DataMapper
---------------------------------

So you found a bug in one (or more) of the DataMapper gems and you think
that you know how to fix it.

Please don't let the fact that these instructions currently end
here, stop you from working on your patch! We'll make sure to update
this README once the tasks actually work reliably!

