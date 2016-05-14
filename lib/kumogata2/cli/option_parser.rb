module Kumogata2::CLI
  class OptionParser
    DEFAULT_OPTIONS = {
      result_log: File.join(Dir.pwd, 'result.json'),
      command_result_log: File.join(Dir.pwd, 'command_result.json'),
      color: $stdout.tty?,
    }

    COMMANDS = {
      describe: {
        description: 'Describe a specified stack',
        arguments: [:stack_name],
      },
      create: {
        description: 'Create resources as specified in the template',
        arguments: [:path_or_url, :stack_name?],
        output: false,
      },
      update: {
        description: 'Update a stack as specified in the template',
        arguments: [:path_or_url, :stack_name],
        output: false,
      },
      delete: {
        description: 'Delete a specified stack',
        arguments: [:stack_name],
        output: false,
      },
      validate: {
        description: 'Validate a specified template',
        arguments: [:path_or_url],
        output: false,
      },
      list: {
        description: 'List summary information for stacks',
        arguments: [:stack_name?],
      },
      export: {
        description: 'Export a template from a specified stack',
        arguments: [:stack_name],
      },
      convert: {
        description: 'Convert a template format',
        arguments: [:path_or_url],
      },
      diff: {
        description: 'Compare templates logically (file, http://..., stack://...)',
        arguments: [:path_or_url1, :path_or_url2],
      },
      dry_run: {
        description: 'Create a change set and show it',
        arguments: [:path_or_url, :stack_name],
      },
      show_events: {
        description: 'Show events for a specified stack',
        arguments: [:stack_name],
      },
      show_outputs: {
        description: 'Show outputs for a specified stack',
        arguments: [:stack_name],
      },
      show_resources: {
        description: 'Show resources for a specified stack',
        arguments: [:stack_name],
      },
      template_summary: {
        description: 'Show template information for a specified stack',
        arguments: [:path_or_url],
      },
    }

    class << self
      def parse!(argv)
        self.new.parse!(argv)
      end
    end # of class methods

    def parse!(argv)
      command = nil
      arguments = nil
      options = {aws: {}}

      opt = ::OptionParser.new
      opt.summary_width = 65535
      set_usage!(opt)

      opt.on('-k', '--access-key ACCESS_KEY') {|v| options[:aws][:access_key_id]     = v }
      opt.on('-s', '--secret-key SECRET_KEY') {|v| options[:aws][:secret_access_key] = v }
      opt.on('-r', '--region REGION')         {|v| options[:aws][:region]            = v }

      opt.on('', '--profile PROFILE') do |v|
        options[:aws][:credentials] ||= {}
        options[:aws][:credentials][:profile_name] = v
      end

      opt.on('', '--credentials-path PATH') do |v|
        options[:aws][:credentials] ||= {}
        options[:aws][:credentials][:path] = v
      end

      plugin_exts = Kumogata2::Plugin.plugins.flat_map(&:ext).uniq
      opt.on(''  , '--output-format FORMAT', plugin_exts) do |v|
        options[:output_format] = v
      end

      opt.on('-p', '--parameters KEY_VALUES', Array) {|v| options[:parameters]              = v }
      opt.on('-j', '--json-parameters JSON')         {|v| options[:json_parameters]         = v }
      opt.on(''  , '--[no-]deletion-policy-retain')  {|v| options[:deletion_policy_retain]  = v }

      {
        disable_rollback: :boolean,
        timeout_in_minutes: Integer,
        notification_arns: Array,
        capabilities: Array,
        resource_types: Array,
        on_failure: nil,
        stack_policy_body: nil,
        stack_policy_url: nil,
        use_previous_template: :boolean,
        stack_policy_during_update_body: nil,
        stack_policy_during_update_url: nil,
      }.each do |key, type|
        opt_str = key.to_s.gsub('_', '-')
        opt_val = key.to_s.upcase

        case type
        when :boolean
          opt.on('', "--[no-]#{opt_str}") {|v| options[key] = v }
        when nil
          opt.on('', "--#{opt_str} #{opt_val}") {|v| options[key] = v }
        else
          opt.on('', "--#{opt_str} #{opt_val}", type) {|v| options[key] = v }
        end
      end

      opt.on(''  , '--result-log PATH')         {|v| options[:result_log]       = v }
      opt.on(''  , '--command-result-log PATH') {|v| options[:command]          = v }
      opt.on(''  , '--[no-]detach')             {|v| options[:detach]           = v }
      opt.on(''  , '--[no-]force')              {|v| options[:force]            = v }
      opt.on(''  , '--[no-]color')              {|v| options[:color]            = v }
      opt.on(''  , '--[no-]ignore-all-space')   {|v| options[:ignore_all_space] = v }
      opt.on(''  , '--[no-]debug')              {|v| options[:debug]            = v }

      opt.parse!

      unless (command = argv.shift)
        puts opt.help
        exit_parse!(1)
      end

      orig_command = command
      command = command.gsub('-', '_').to_sym

      unless COMMANDS.has_key?(command)
        raise "Unknown command: #{orig_command}"
      end

      arguments = argv.dup
      validate_arguments(command, arguments)

      options = DEFAULT_OPTIONS.merge(options)
      options = Hashie::Mash.new(options)

      if options[:aws][:credentials]
        credentials = Aws::SharedCredentials.new(options[:aws][:credentials])
        options[:aws][:credentials] = credentials
      end

      Aws.config.update(options[:aws].dup)
      options = Hashie::Mash.new(options)

      String.colorize = options.color?
      Diffy::Diff.default_format = options.color? ? :color : :text

      if options.debug?
        Kumogata2::Logger.instance.set_debug(options.debug?)

        Aws.config.update(
          :http_wire_trace => true,
          :logger => Kumogata2::Logger.instance
        )
      end

      update_parameters(options)
      output = COMMANDS.fetch(command).fetch(:output, true)

      options.command = command
      options.arguments = arguments
      options.output_result = output

      [command, arguments, options, output]
    end

    private

    def exit_parse!(exit_code)
      exit(exit_code)
    end

    def set_usage!(opt)
      opt.banner = "Usage: kumogata2 <command> [args] [options]"
      opt.separator ''
      opt.separator 'Commands:'

      cmd_max_len = COMMANDS.keys.map {|i| i.to_s.length }.max

      cmd_arg_descs = COMMANDS.map do |command, attributes|
        command = command.to_s.gsub('_', '-')
        description = attributes.fetch(:description)
        arguments = attributes.fetch(:arguments)

        [
          '%-*s %s' % [cmd_max_len, command, arguments_to_message(arguments)],
          description,
        ]
      end

      cmd_arg_max_len = cmd_arg_descs.map {|i| i[0].length }.max

      opt.separator(cmd_arg_descs.map {|cmd_arg, desc|
        '  %-*s  %-s' % [cmd_arg_max_len, cmd_arg, desc]
      }.join("\n"))

      opt.separator ''
      opt.separator 'Plugins: '

      Kumogata2::Plugin.plugins.each do |plugin|
        opt.separator "  #{plugin.name}: #{plugin.ext.join(', ')}"
      end

      opt.separator ''
      opt.separator 'Options:'
    end

    def arguments_to_message(arguments)
      arguments.map {|i| i.to_s.sub(/(.+)\?\z/) { "[#{$1}]" }.upcase }.join(' ')
    end

    def validate_arguments(command, arguments)
      expected = COMMANDS[command][:arguments] || []

      min = expected.count {|i| i.to_s !~ /\?\z/ }
      max = expected.length

      if arguments.length < min or max < arguments.length
        raise "Usage: kumogata #{command} #{arguments_to_message(expected)} [options]"
      end
    end

    def update_parameters(options)
      parameters = {}

      (options.parameters || []).each do |i|
        key, value = i.split('=', 2)
        parameters[key] = value
      end

      if options.json_parameters
        parameters.merge!(JSON.parse(options.json_parameters))
      end

      options.parameters = parameters
    end
  end # OptionParser
end # Kumogata2::CLI
