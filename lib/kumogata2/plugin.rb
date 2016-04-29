module Kumogata2::Plugin
  class << self
    def register(name, exts, klass)
      name = name.to_s
      @plugins ||= {}

      if @plugins.has_key?(name)
        raise "Plugin has already been registered: #{name}"
      end

      @plugins[name] = {
        class: klass,
        ext: exts.map(&:to_s),
      }
    end

    def find(ext)
      plgns = @plugins.to_a.reverse

      plugin_name, plugin_attrs = plgns.find do |name, attrs|
        attrs[:ext].include?(ext)
      end

      plugin_attrs ? plugin_attrs[:class] : nil
    end

    def plugin_exts
      @plugins.flat_map {|name, attrs|
        attrs[:ext]
      }.uniq
    end

    def load_plugins
      plgns = Gem::Specification.find_all.select {|i| i.name =~ /\Akumogata2-plugin-/ }

      plgns.each do |plgns_spec|
        name = plgns_spec.name
        path = File.join(name.split('-').slice(0, 3))

        begin
          require path
        rescue LoadError => e
          Kumogata2::Logger::Helper.log(:warn, "Cannot load plugin: #{name}: #{e}", color: :yellow)
        end
      end
    end
  end # of class methods
end # Kumogata2::Plugin
