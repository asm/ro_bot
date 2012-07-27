# This script is useful for playing around in the sandbox since it's such a
# hostile place.

#!/usr/bin/env ruby

require 'rubygems'
require 'sandbox'
require 'pstore'
require 'ruby-debug'

Debugger.start

sandbox = Sandbox.safe

# Lock down the sandbox
sandbox.activate!

# Inject stored definitions into the sandbox
store = PStore.new('methods.pstore')
store.transaction do
  methods = store['methods']

  if methods.is_a?(Array)
    begin
      methods.each do |string_def|
        sandbox.eval(string_def)
      end
    rescue => e
      raise "Caught exception while loading defs: #{e.inspect}"
    end
  end
end

debugger;1
