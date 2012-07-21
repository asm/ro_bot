class PrivMessage
  attr_accessor :to, :text

  def initialize(to, text)
    self.to   = to
    self.text = text
  end
end
