require 'sandbox'
require 'xmpp4r'
require 'xmpp4r/muc/helper/simplemucclient'
require 'pstore'

require 'lib/priv_message.rb'
require 'lib/priv_message_stack.rb'

unless JRUBY_VERSION == '1.6.3'
  warn 'This bot is only known to work with JRuby 1.6.3'
  exit 1
end

class Bot
  attr_accessor :config, :client, :muc, :sandbox, :roster

  def initialize(config)
    self.config  = config
    self.client  = Jabber::Client.new(config[:jid])
    self.muc     = Jabber::MUC::MUCClient.new(client)
    self.sandbox = Sandbox.safe
    self.roster  = {}

    # Lock down the sandbox
    self.sandbox.activate!

    # Inject messaging classes into the sandbox
    self.sandbox.eval(<<-ruby)
      class PrivMessage
        attr_accessor :to, :text
      
        def initialize(to, text)
          self.to = to
          self.text = text
        end
      end
      class PrivMessageStack < Array
      end
    ruby

    # Inject stored definitions into the sandbox
    store = PStore.new('methods.pstore')
    store.transaction do
      methods = store['methods']

      if methods.is_a?(Array)
        begin
          methods.each do |string_def|
            self.sandbox.eval(string_def)
          end
        rescue => e
          raise "Caught exception while loading defs: #{e.inspect}"
        end
      end
    end

    if Jabber.logger = config[:debug]
      Jabber.debug = true
    end

    self
  end

  def connect
    client.connect
    client.auth(config[:password])
    client.send(Jabber::Presence.new.set_type(:available))

    salutation = config[:nick].split(/\s+/).first

    # Register callbacks
    muc.add_join_callback do |presence|
      name = presence.from.resource
      addr = presence.x.elements['item affiliation'].jid.to_s

      return if name =~ /Ro Bot/

      self.roster[name] = addr
    end

    muc.add_leave_callback do |presence|
      name = presence.from.resource
      addr = presence.x.elements['item affiliation'].jid.to_s

      self.roster.delete(name)
    end

    muc.add_message_callback do |msg|
      next unless msg.body =~ /^@?#{salutation}:*\s+(.+)$/i or msg.body =~ /^!(.+)$/

      sender = msg.x.elements['sender'].text
      process(sender, msg.from.resource, $1)
    end

    muc.join(config[:room] + '/' + config[:nick])

    self
  end

  def process(sender, from, command)
    # Don't process our own input
    return if from =~ /Ro Bot/

    # Overriding method missing is just lame
    return if command =~ /def method_missing/

    warn "command: #{from}> #{command}"
    firstname = from.split(/ /).first

    response = ''
    begin
      # Inject the room roster
      self.sandbox.eval(<<-ruby)
        $ROSTER = #{self.roster.keys.inspect}
      ruby

      response = self.sandbox.eval(command)

      # Store the command after the fact in case it raises
      if command =~ /^def /
        # Store this shit for the lols
        store = PStore.new('methods.pstore')

        store.transaction do
          methods = store['methods']

          # nil means we're starting from scratch
          if methods.nil?
            store['methods'] = [command]
          else
            store['methods'] << command
          end
        end
      end
    rescue Sandbox::SandboxException => e
      response = e.message
    end

    # response handler
    case response
    when String
      respond response
    when PrivMessage
      priv_message(response)
    when PrivMessageStack
      response.each do |pmsg|
        priv_message(pmsg)
      end
    else
      respond response.inspect
    end
  end

  def respond(msg)
    muc.send Jabber::Message.new(muc.room, msg)
  end

  def priv_message(msg)
    addr    = self.roster[msg.to]
    message = Jabber::Message.new(addr, msg.text)

    message.set_type(:chat).set_id('1')
    client.send(message)
  end

  def run
    warn "running"
    loop { sleep 1 }
  end

  # For the day when we can connect multiple times and listen on multiple chat
  # rooms: Bot.run(settings)
  def self.run(config)
    bots = []

    config[:rooms].each do |room|
      config[:room] = room
      bots << Bot.new(config).connect
    end

    bots.last.run
  end
end
