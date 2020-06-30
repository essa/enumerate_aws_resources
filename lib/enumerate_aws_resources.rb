require "enumerate_aws_resources/version"

class EnumerateAwsResources
  def initialize(aws_client, *args, **options)
    @aws_client = aws_client
    @args = args
    @list_max = options[:list_max] || 100
    @describe_max = options[:describe_max] || 10
    @result_attribute_name = options[:result_attribute_name]
    @arn_attribute_name = options[:arn_attribute_name]
    @describe_option = options[:describe_option]
    @trace = options[:trace] || false
  end

  private
  def _enumerate_arn(resource, *args, **options)
    Enumerator.new do |y|
      next_token = nil
      loop do
        opt = options.merge(
          next_token: next_token,
          max_results: @list_max
        )
        puts "#{list_method_name(resource)}(#{opt.inspect})" if @trace
        resp = @aws_client.send(list_method_name(resource), opt)
        resp.send(identifier_name(resource)).each(&y)
        next_token = resp.next_token
        break unless next_token
      end
    end
  end

  def pluralize(resource)
    "#{resource}s"
  end

  def list_method_name(resource)
    "list_#{pluralize(resource)}"
  end

  def describe_method_name(resource)
    "describe_#{pluralize(resource)}"
  end

  def identifier_name(resource)
    "#{resource}_arns"
  end

  def arn_attribute_name(resource)
    @arn_attribute_name || pluralize(resource)
  end

  def result_attribute_name(resource)
    @result_attribute_name || pluralize(resource)
  end

  def _enumerate(resource, *args, **options)
    describe_opt = @describe_option || options
    arns = _enumerate_arn(resource, *args, **options)
    Enumerator.new do |y|
      arns.each_slice(@describe_max) do |arns|
        opt = describe_opt.merge(
          arn_attribute_name(resource).to_sym => arns
        )
        puts "#{describe_method_name(resource)}(#{opt.inspect})" if @trace
        resp = @aws_client.send(describe_method_name(resource), opt)
        resp.send(result_attribute_name(resource)).each(&y)
      end
    end
  end

  def method_missing(sym, *args, **options)
    case sym.to_s
    when /^enumerate_(\w+)$/
      _enumerate($1, *args, **options)
    else
      super
    end
  end

end
