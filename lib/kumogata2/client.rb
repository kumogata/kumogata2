class Kumogata2::Client
  include Kumogata2::Logger::Helper

  def initialize(options)
    @options = options.kind_of?(Hashie::Mash) ? options : Hashie::Mash.new(options)
    @client = nil
    @resource = nil
    @plugin_by_ext = {}
  end

  def describe(stack_name)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name)
    stack = describe_stack(stack_name)
    JSON.pretty_generate(stack).colorize_as(:json)
  end

  def create(path_or_url, stack_name = nil)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name) if stack_name
    template = open_template(path_or_url)
    update_deletion_policy(template, delete_stack: !stack_name)

    outputs = create_stack(template, stack_name)

    unless @options.detach?
      post_process(path_or_url, outputs)
    end
  end

  def update(path_or_url, stack_name)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name)
    template = open_template(path_or_url)
    update_deletion_policy(template, update_metadate: true)

    outputs = update_stack(template, stack_name)

    unless @options.detach?
      post_process(path_or_url, outputs)
    end
  end

  def delete(stack_name)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name)
    get_resource.stack(stack_name).stack_status

    if @options.force? or agree("Are you sure you want to delete `#{stack_name}`? ".yellow)
      delete_stack(stack_name)
    end
  end

  def validate(path_or_url)
    template = open_template(path_or_url)
    validate_template(template)
  end

  def list(stack_name = nil)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name) if stack_name
    stacks = describe_stacks(stack_name)
    JSON.pretty_generate(stacks).colorize_as(:json)
  end

  def export(stack_name)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name)
    template = export_template(stack_name)
    convert0(template)
  end

  def convert(path_or_url)
    template = open_template(path_or_url)
    convert0(template)
  end

  def diff(path_or_url1, path_or_url2)
    templates = [path_or_url1, path_or_url2].map do |path_or_url|
      template = nil

      if path_or_url =~ %r|\Astack://(.*)|
        stack_name = $1 || ''
        validate_stack_name(stack_name)
        template = export_template(stack_name)
      else
        template = open_template(path_or_url)
      end

      template = Kumogata2::Utils.stringify(template)
      JSON.pretty_generate(template)
    end

    diff_opts = @options.ignore_all_space? ? '-uw' : '-u'
    opts = {:include_diff_info => true, :diff => diff_opts}
    diff = Diffy::Diff.new(*templates, opts).to_s

    diff.sub(/^(\e\[\d+m)?\-\-\-(\s+)(\S+)/m) { "#{$1}---#{$2}#{path_or_url1}"}
        .sub(/^(\e\[\d+m)?\+\+\+(\s+)(\S+)/m) { "#{$1}+++#{$2}#{path_or_url2}"}
  end

  def dry_run(path_or_url, stack_name = nil)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name) if stack_name
    template = open_template(path_or_url)
    update_deletion_policy(template, delete_stack: !stack_name)
    changes = show_change_set(template, stack_name)
    changes = JSON.pretty_generate(changes).colorize_as(:json) if changes
    changes
  end

  def show_events(stack_name)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name)
    events = describe_events(stack_name)
    JSON.pretty_generate(events).colorize_as(:json)
  end

  def show_outputs(stack_name)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name)
    outputs = describe_outputs(stack_name)
    JSON.pretty_generate(outputs).colorize_as(:json)
  end

  def show_resources(stack_name)
    stack_name = normalize_stack_name(stack_name)
    validate_stack_name(stack_name)
    resources = describe_resources(stack_name)
    JSON.pretty_generate(resources).colorize_as(:json)
  end

  def template_summary(path_or_url)
    params = {}

    if path_or_url =~ %r|\Astack://(.*)|
      stack_name = $1 || ''
      validate_stack_name(stack_name)
      params[:stack_name] = stack_name
    else
      template = open_template(path_or_url)
      params[:template_body] = JSON.pretty_generate(template)
    end

    summary = describe_template_summary(params)
    JSON.pretty_generate(summary).colorize_as(:json)
  end

  private

  def get_client
    return @client unless @client.nil?
    @client = Aws::CloudFormation::Client.new(@options.aws)
  end

  def get_resource
    return @resource unless @resource.nil?
    get_client if @client.nil?
    @resource = Aws::CloudFormation::Resource.new(client: @client)
  end

  def describe_stack(stack_name)
    resp = get_client.describe_stacks(stack_name: stack_name)
    resp.stacks.first.to_h
  end

  def create_stack(template, stack_name)
    stack_will_be_deleted = !stack_name

    unless stack_name
      stack_name = random_stack_name
    end

    log(:info, "Creating stack: #{stack_name}", color: :cyan)

    params = {
      stack_name: stack_name,
      template_body: template.to_json,
      parameters: parameters_array,
    }

    params.merge!(set_api_params(params,
      :disable_rollback,
      :timeout_in_minutes,
      :notification_arns,
      :capabilities,
      :resource_types,
      :on_failure,
      :stack_policy_body,
      :stack_policy_url)
    )

    stack = get_resource.create_stack(params)

    return if @options.detach?

    completed = wait(stack, 'CREATE_COMPLETE')

    unless completed
      raise_stack_error!(stack, 'Create failed')
    end

    outputs = outputs_for(stack)
    summaries = resource_summaries_for(stack)

    if stack_will_be_deleted
      delete_stack(stack_name)
    end

    output_result(stack_name, outputs, summaries)

    outputs
  end

  def update_stack(template, stack_name)
    stack = get_resource.stack(stack_name)
    stack.stack_status

    log(:info, "Updating stack: #{stack_name}", color: :green)

    params = {
      stack_name: stack_name,
      template_body: template.to_json,
      parameters: parameters_array,
    }

    params.merge!(set_api_params(params,
      :use_previous_template,
      :stack_policy_during_update_body,
      :stack_policy_during_update_url,
      :notification_arns,
      :capabilities,
      :resource_types,
      :stack_policy_body,
      :stack_policy_url)
    )

    event_log = create_event_log(stack)
    stack.update(params)

    return if @options.detach?

    # XXX: Reacquire the stack
    stack = get_resource.stack(stack_name)
    completed = wait(stack, 'UPDATE_COMPLETE', event_log)

    unless completed
      raise_stack_error!(stack, 'Update failed')
    end

    outputs = outputs_for(stack)
    summaries = resource_summaries_for(stack)

    output_result(stack_name, outputs, summaries)

    outputs
  end

  def delete_stack(stack_name)
    stack = get_resource.stack(stack_name)
    stack.stack_status

    log(:info, "Deleting stack: #{stack_name}", color: :red)
    event_log = create_event_log(stack)
    stack.delete

    return if @options.detach?

    completed = false

    begin
      # XXX: Reacquire the stack
      stack = get_resource.stack(stack_name)
      completed = wait(stack, 'DELETE_COMPLETE', event_log)
    rescue Aws::CloudFormation::Errors::ValidationError
      # Handle `Stack does not exist`
      completed = true
    end

    unless completed
      raise_stack_error!(stack, 'Delete failed')
    end

    log(:info, 'Success')
  end

  def validate_template(template)
    get_client.validate_template(template_body: template.to_json)
    log(:info, 'Template validated successfully', color: :green)
  end

  def describe_stacks(stack_name)
    params = {}
    params[:stack_name] = stack_name if stack_name

    get_resource.stacks(params).map do |stack|
      {
        'StackName'    => stack.name,
        'CreationTime' => stack.creation_time,
        'StackStatus'  => stack.stack_status,
        'Description'  => stack.description,
      }
    end
  end

  def export_template(stack_name)
    stack = get_resource.stack(stack_name)
    stack.stack_status
    template = stack.client.get_template(stack_name: stack_name).template_body
    JSON.parse(template)
  end

  def show_change_set(template, stack_name)
    output = nil
    change_set_name = [stack_name, SecureRandom.uuid].join('-')

    log(:info, "Creating ChangeSet: #{change_set_name}", color: :cyan)

    params = {
      stack_name: stack_name,
      change_set_name: change_set_name,
      template_body: template.to_json,
      parameters: parameters_array,
    }

    params.merge!(set_api_params(params,
      :use_previous_template,
      :notification_arns,
      :capabilities,
      :resource_types)
    )

    resp = get_client.create_change_set(params)
    change_set_arn = resp.id

    completed, change_set = wait_change_set(change_set_arn, 'CREATE_COMPLETE')

    if completed
      output = changes_for(change_set)
    else
      log(:error, "Create ChangeSet failed: #{change_set.status_reason}", color: :red)
    end

    log(:info, "Deleting ChangeSet: #{change_set_name}", color: :red)

    get_client.delete_change_set(change_set_name: change_set_arn)

    begin
      completed, _ = wait_change_set(change_set_arn, 'DELETE_COMPLETE')
    rescue Aws::CloudFormation::Errors::ChangeSetNotFound
      # Handle `ChangeSet does not exist`
      completed = true
    end

    unless completed
      log(:error, "Delete ChangeSet failed: #{change_set.status_reason}", color: :red)
    end

    output
  end

  def describe_events(stack_name)
    stack = get_resource.stack(stack_name)
    stack.stack_status
    events_for(stack)
  end

  def describe_outputs(stack_name)
    stack = get_resource.stack(stack_name)
    stack.stack_status
    outputs_for(stack)
  end

  def describe_resources(stack_name)
    stack = get_resource.stack(stack_name)
    stack.stack_status
    resource_summaries_for(stack)
  end

  def describe_template_summary(params)
    resp = get_client.get_template_summary(params)
    resp.to_h
  end

  def convert0(template)
    ext = @options.output_format || 'template'
    plugin = find_or_create_plugin('xxx.' + ext)

    if plugin
      plugin.dump(template)
    else
      raise "Unknown format: #{ext}"
    end
  end

  def open_template(path_or_url)
    plugin = find_or_create_plugin(path_or_url)

    if plugin
      @options.path_or_url = path_or_url
      plugin.parse(open(path_or_url, &:read))
    else
      raise "Unknown format: #{path_or_url}"
    end
  end

  def find_or_create_plugin(path_or_url)
    ext = File.extname(path_or_url).sub(/\A\./, '')

    if @plugin_by_ext.has_key?(ext)
      return @plugin_by_ext.fetch(ext)
    end

    plugin_class = Kumogata2::Plugin.find_by_ext(ext)
    plugin = plugin_class ? plugin_class.new(@options) : nil
    @plugin_by_ext[ext] = plugin
  end

  def update_deletion_policy(template, options = {})
    if options[:delete_stack] or @options.deletion_policy_retain?
      template['Resources'].each do |k, v|
        next if /\AAWS::CloudFormation::/ =~ v['Type']
        v['DeletionPolicy'] ||= 'Retain'

        if options[:update_metadate]
          v['Metadata'] ||= {}
          v['Metadata']['DeletionPolicyUpdateKeyForKumogata'] = "DeletionPolicyUpdateValueForKumogata#{Time.now.to_i}"
        end
      end
    end
  end

  def validate_stack_name(stack_name)
    unless /\A[a-zA-Z][-a-zA-Z0-9]*\Z/i =~ stack_name
      raise "1 validation error detected: Value '#{stack_name}' at 'stackName' failed to satisfy constraint: Member must satisfy regular expression pattern: [a-zA-Z][-a-zA-Z0-9]*"
    end
  end

  def parameters_array
    @options.parameters.map do |key, value|
      {parameter_key: key, parameter_value: value}
    end
  end

  def set_api_params(params, *keys)
    {}.tap do |h|
      keys.each do |k|
        h[k] = @options[k] if @options[k]
      end
    end
  end

  def wait(stack, complete_status, event_log = {})
    before_wait = proc do |attempts, response|
      print_event_log(stack, event_log)
    end

    stack.wait_until(before_wait: before_wait, max_attempts: nil, delay: 1) do |s|
      s.stack_status !~ /_IN_PROGRESS\z/
    end

    print_event_log(stack, event_log)

    completed = (stack.stack_status == complete_status)
    log(:info, completed ? 'Success' : 'Failure')

    completed
  end

  def wait_change_set(change_set_name, complete_status)
    change_set = nil

    loop do
      change_set = get_client.describe_change_set(change_set_name: change_set_name)

      if change_set.status !~ /(_PENDING|_IN_PROGRESS)\z/
        break
      end

      sleep 1
    end

    completed = (change_set.status == complete_status)
    [completed, change_set]
  end

  def print_event_log(stack, event_log)
    events_for(stack).sort_by {|i| i['Timestamp'] }.each do |event|
      event_id = event['EventId']

      unless event_log[event_id]
        event_log[event_id] = event

        timestamp = event['Timestamp']
        summary = {}

        ['LogicalResourceId', 'ResourceStatus', 'ResourceStatusReason'].map do |k|
          summary[k] = event[k]
        end

        puts [
          timestamp.getlocal.strftime('%Y/%m/%d %H:%M:%S %Z'),
          summary.to_json.colorize_as(:json),
        ].join(': ')
      end
    end
  end

  def create_event_log(stack)
    event_log = {}

    events_for(stack).sort_by {|i| i['Timestamp'] }.each do |event|
      event_id = event['EventId']
      event_log[event_id] = event
    end

    return event_log
  end

  def events_for(stack)
    stack.events.map do |event|
      event_hash = {}

      [
        :event_id,
        :logical_resource_id,
        :physical_resource_id,
        :resource_properties,
        :resource_status,
        :resource_status_reason,
        :resource_type,
        :stack_id,
        :stack_name,
        :timestamp,
      ].each do |k|
        event_hash[Kumogata2::Utils.camelize(k)] = event.send(k)
      end

      event_hash
    end
  end

  def outputs_for(stack)
    outputs_hash = {}

    stack.outputs.each do |output|
      outputs_hash[output.output_key] = output.output_value
    end

    outputs_hash
  end

  def resource_summaries_for(stack)
    stack.resource_summaries.map do |summary|
      summary_hash = {}

      [
        :logical_resource_id,
        :physical_resource_id,
        :resource_type,
        :resource_status,
        :resource_status_reason,
        :last_updated_timestamp
      ].each do |k|
        summary_hash[Kumogata2::Utils.camelize(k)] = summary.send(k)
      end

      summary_hash
    end
  end

  def changes_for(change_set)
    change_set.changes.map do |change|
      resource_change = change.resource_change
      change_hash = {}

      [
        :action,
        :logical_resource_id,
        :physical_resource_id,
        :resource_type,
      ].each do |k|
        change_hash[Kumogata2::Utils.camelize(k)] = resource_change[k]
      end

      change_hash['Details'] = resource_change.details.map do |detail|
        {
          attribute: detail.target.attribute,
          name: detail.target.name,
        }
      end

      change_hash
    end
  end

  def output_result(stack_name, outputs, summaries)
    puts <<-EOS

Stack Resource Summaries:
#{JSON.pretty_generate(summaries).colorize_as(:json)}

Outputs:
#{JSON.pretty_generate(outputs).colorize_as(:json)}
EOS

    if @options.result_log?
      puts <<-EOS

(Save to `#{@options.result_log}`)
      EOS

      open(@options.result_log, 'wb') do |f|
        f.puts JSON.pretty_generate({
          'StackName' => stack_name,
          'StackResourceSummaries' => summaries,
          'Outputs' => outputs,
        })
      end
    end
  end

  def post_process(path_or_url, outputs)
    plugin = find_or_create_plugin(path_or_url)

    if plugin and plugin.respond_to?(:post)
      plugin.post(outputs)
    end
  end

  def raise_stack_error!(stack, message)
    errmsgs = [message]
    errmsgs << stack.name
    errmsgs << stack.stack_status_reason if stack.stack_status_reason
    raise errmsgs.join(': ')
  end

  def random_stack_name
    stack_name = ['kumogata']
    user_host = Kumogata2::Utils.get_user_host
    stack_name << user_host if user_host
    stack_name << SecureRandom.uuid
    stack_name = stack_name.join('-')
    stack_name.gsub(/[^-a-zA-Z0-9]+/, '-').gsub(/-+/, '-')
  end

  def normalize_stack_name(stack_name)
    if %r|\Astack://| =~ stack_name
      stack_name.sub(%r|\Astack://|, '')
    else
      stack_name
    end
  end
end
