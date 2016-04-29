class Kumogata2::Logger < ::Logger
  include Singleton

  def initialize
    super($stdout)

    self.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end

    self.level = Logger::INFO
  end

  def set_debug(value)
    self.level = value ? Logger::DEBUG : Logger::INFO
  end

  module Helper
    def log(level, message, log_options = {})
      globa_options = @options || {}
      message = "[#{level.to_s.upcase}] #{message}" unless level == :info
      message = message.send(log_options[:color]) if log_options[:color]
      logger = globa_options[:logger] || Kumogata2::Logger.instance
      logger.send(level, message)
    end
    module_function :log
  end
end
