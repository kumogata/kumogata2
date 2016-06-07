# Kumogata2

Kumogata2 is a tool for [AWS CloudFormation](https://aws.amazon.com/cloudformation/).

This is a `format converter` + `useful tool`.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kumogata2'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kumogata2

## Usage

```
Usage: kumogata2 <command> [args] [options]

Commands:
  describe         STACK_NAME                 Describe a specified stack
  create           PATH_OR_URL [STACK_NAME]   Create resources as specified in the template
  update           PATH_OR_URL STACK_NAME     Update a stack as specified in the template
  delete           STACK_NAME                 Delete a specified stack
  validate         PATH_OR_URL                Validate a specified template
  list             [STACK_NAME]               List summary information for stacks
  export           STACK_NAME                 Export a template from a specified stack
  convert          PATH_OR_URL                Convert a template format
  diff             PATH_OR_URL1 PATH_OR_URL2  Compare templates logically (file, http://..., stack://...)
  dry-run          PATH_OR_URL STACK_NAME     Create a change set and show it
  show-events      STACK_NAME                 Show events for a specified stack
  show-outputs     STACK_NAME                 Show outputs for a specified stack
  show-resources   STACK_NAME                 Show resources for a specified stack
  template-summary PATH_OR_URL                Show template information for a specified stack

Support Format:
  json, js, template

Options:
    -k, --access-key ACCESS_KEY
    -s, --secret-key SECRET_KEY
    -r, --region REGION
        --profile PROFILE
        --credentials-path PATH
        --output-format FORMAT
    -p, --parameters KEY_VALUES
    -j, --json-parameters JSON
        --[no-]deletion-policy-retain
        --[no-]disable-rollback
        --timeout-in-minutes TIMEOUT_IN_MINUTES
        --notification-arns NOTIFICATION_ARNS
        --capabilities CAPABILITIES
        --resource-types RESOURCE_TYPES
        --on-failure ON_FAILURE
        --stack-policy-body STACK_POLICY_BODY
        --stack-policy-url STACK_POLICY_URL
        --[no-]use-previous-template
        --stack-policy-during-update-body STACK_POLICY_DURING_UPDATE_BODY
        --stack-policy-during-update-url STACK_POLICY_DURING_UPDATE_URL
        --result-log PATH
        --command-result-log PATH
        --[no-]detach
        --[no-]force
        --[no-]color
        --[no-]ignore-all-space
        --[no-]debug
```

### Environment variables

```sh
export AWS_SECRET_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE
export AWS_ACCESS_KEY_ID=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_REGION=us-east-1
```

### Create resources

    $ kumogata2 create template.rb

If you want to save the stack, please specify the stack name:

    $ kumogata2 create template.rb any_stack_name

If you want to pass parameters, please use `-p` option:

    $ kumogata2 create template.rb -p "InstanceType=m1.large,KeyName=any_other_key"


**Notice**

**The stack will be delete if you do not specify the stack name explicitly.**
(And only the resources will remain)

## Plugin

Kumogata2 can be extended with plug-ins, such as the following:

```ruby
class Kumogata2::Plugin::JSON
  Kumogata2::Plugin.register(:json, ['json', 'js', 'template'], self)

  def initialize(options)
    @options = options
  end

  def parse(str)
    JSON.parse(str)
  end

  def dump(hash)
    JSON.pretty_generate(hash).colorize_as(:json)
  end
end
```

see [kumogata2-plugin-ruby](https://github.com/winebarrel/kumogata2-plugin-ruby).

## Similar tools
* [Codenize.tools](http://codenize.tools/)
