class Kumogata2::Utils
  class << self
    def camelize(str)
      str.to_s.split(/[-_]/).map {|i|
        i[0, 1].upcase + i[1..-1].downcase
      }.join
    end

    def filter_backtrace(backtrace)
      filter_path = ['(eval)']

      if defined?(Gem)
        filter_path.concat(Gem.path)
        filter_path << Gem.bindir
      end

      RbConfig::CONFIG.select {|k, v|
        k.to_s =~ /libdir/
      }.each {|k, v| filter_path << v }

      filter_path = filter_path.map {|i| /\A#{Regexp.escape(i)}/ }

      backtrace.select do |path|
        path = path.split(':', 2).first
        not filter_path.any? {|i| i =~ path }
      end
    end

    def get_user_host
      user = `whoami`.strip rescue ''
      host = `hostname`.strip rescue ''
      user_host = [user, host].select {|i| not i.empty? }.join('-')
      user_host.empty? ? nil : user_host
    end

    def stringify(obj)
      case obj
      when Array
        obj.map {|v| stringify(v) }
      when Hash
        hash = {}

        obj.each do |k, v|
          hash[stringify(k)] = stringify(v)
        end

        hash
      else
        obj.to_s
      end
    end
  end # of class methods
end
