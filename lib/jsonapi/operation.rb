module JSONAPI
  class Operation
    attr_reader :resource_klass, :operation_type, :options

    def initialize(operation_type, resource_klass, options)
      @operation_type = operation_type
      @resource_klass = resource_klass
      @options = options
    end

    def process
      processor.process
    end

    private
    def processor
      self.class.processor_instance_for(resource_klass, operation_type, options)
    end

    class << self
      def processor_instance_for(resource_klass, operation_type, params)
        _processor_from_resource_type(resource_klass).new(resource_klass, operation_type, params)
      end

      def _processor_from_resource_type(resource_klass)
        processor = _get_resource_name(resource_klass).safe_constantize
        if processor.nil?
          processor = JSONAPI.configuration.default_processor_klass
        end

        return processor
      end

      private

      def _get_resource_name(resource_klass)
        resource_klass.get_processor_class || resource_klass.name.gsub(/Resource$/,'Processor')
      end

    end
  end
end
