# Iodine

Iodine makes writing evented server applications easy to write.

Iodine is intended to replace the use of a generic reacor, such as EventMachine or GReactor and it hides all the nasty details of creating the event loop.

To use Iodine, you just set up your tasks - including a single server, if you want one. Iodine will start running once your application is finished and it won't stop runing until all the scheduled tasks have completed.

Iodine v. 0.0.1 isn't well tested just yet... but I'm releasing it anyway, to reserve the name and because initial testing shows that it works.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'iodine'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install iodine

## Simple Usage: Running tasks and shutting down

This mode of operation is effective if you have a `cron`-job that periodically initiates an Iodine Ruby script. It allows the script to easily initiate a task's stack and perform the tasks concurrently.

Iodine starts to work once you app is finished setting all the tasks up (upon exit).

To see how that works, open your `irb` terminal an try this:

```ruby
require 'iodine'

# Iodine supports shutdown hooks
Iodine.on_shutdown { puts "Done!" }
# The last hook is the first scheduled for execution
Iodine.on_shutdown { puts "Finishing up :-)" }

# Setup tasks using the `run` or `callback` methods
Iodine.run do
    # tasks can create more tasks...
    Iodine.run { puts "Task 2 completed!" }
    puts "Task 1 completed!"
end

# set concurrency level (defaults to a single thread).
Iodine.threads = 5

# Iodine will start executing tasks once your script is done.
exit
```

In this mode, Iodine will continue running until all the tasks have completed and than it will quite. Timer based tasks will be ignored.

## Simple Usage: Task polling (unreleased version)

This mode of operation is effective if want Iodine to periodically initiates new tasks, for instance if you cannot use `cron`.

To initiate this mode, simply set: `Iodine.protocol = :timers`

In example:

```ruby
require 'iodine'

# set concurrency level (defaults to a single thread).
Iodine.threads = 5

# set Iodine to keep listening to TimedEvent(s).
Iodine.protocol = :timers

# perform a periodical task every ten seconds
Iodine.run_every 10 do
   Iodine.run { sleep 5; puts " * this could have been a long task..." }
   puts "I could be polling a database to schedule more tasks..."
end

# Iodine will start running once your script is done and it will never stop unless stopped.
exit
```

In this mode, Iodine will continue running until it receives a kill signal (i.e. `^C`). Once the kill signal had been received, Iodine will start shutting down, allowing up to ~20-25 seconds to complete any pending tasks (timeout).

## Server Usage: Plug in your network protocol

Iodine is designed to help write network services (Servers) where each script is intended to implement a single server.

This is not a philosophy based on any idea or preferences, but rather a response to real-world design where each Ruby script is usually assigned a single port for network access (hence, a single server).

To help you write your network service, Iodine starts you off with the `Iodine::Protocol` and `Iodine::SSLProtocol`.

In this mode, Iodine will continue running until it receives a kill signal (i.e. `^C`). Once the kill signal had been received, Iodine will start shutting down, allowing up to ~20-25 seconds to complete any pending tasks (timeout).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/iodine.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
