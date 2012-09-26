2 second example usage:

```ruby
#!/usr/bin/env ruby

require 'rubygems'

require 'lib/bot.rb'

# See https://<your organization>.hipchat.com/account/xmpp for you XMPP login details
# Using resource "/bot" on the user JID prevents HipChat from sending the
# history upon channel join.
settings = {
  :server   => 'conf.hipchat.com',
  :jid      => '<jabber_id>/bot',
  :nick     => '<nickname>',
  :room     => '<room_name>@conf.hipchat.com',
  :password => '<password>',
  :debug    => Logger.new(STDOUT),
}

Bot.new(settings).connect.run
```
