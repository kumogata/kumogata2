module Kumogata2::Plugin
  class << self
    def register(name, exts, klass)
      name = name.to_s
      @plugins ||= Hashie::Mash.new

      if @plugins.has_key?(name)
        Kumogata2::Logger::Helper.log(:warn, "Plugin has already been registered: #{name}", color: :yellow)
      end

      @plugins[name] = {
        name: name,
        type: klass,
        ext: exts.map(&:to_s),
      }
    end

    def find_by_ext(ext)
      plgn = self.plugins.reverse.find do |i|
        i.ext.include?(ext)
      end

      plgn ? plgn.type : nil
    end

    def plugin_by_name
      @plugins
    end

    def plugins
      @plugins.map {|_, v| v }
    end

    def load_plugins
      plgns = Gem::Specification.find_all.select {|i| i.name =~ /\Akumogata2-plugin-/ }

      plgns.each do |plgns_spec|
        name = plgns_spec.name
        path = File.join(name.split('-', 3))

        begin
          require path
        rescue LoadError => e
          Kumogata2::Logger::Helper.log(:warn, "Cannot load plugin: #{name}: #{e}", color: :yellow)
        end
      end
    end
  end # of class methods
end # Kumogata2::Plugin
