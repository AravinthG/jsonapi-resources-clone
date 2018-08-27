# frozen_string_literal: true

require 'jsonapi/filter_helper'

module JSONAPI
  class CustomRequestParser < RequestParser
    include ::JSONAPI::FilterHelper

    def setup_base_op(params)
      return if params.nil?

      resource_klass = Resource.resource_klass_for(params[:controller]) if params[:controller]

      setup_action_method_name = "setup_#{params[:action]}_action"
      if respond_to?(setup_action_method_name)
        raise params[:_parser_exception] if params[:_parser_exception]
        send(setup_action_method_name, params, resource_klass)
      else
        send('setup_additional_methods', params[:action].to_sym, params, resource_klass)
      end
    rescue ActionController::ParameterMissing => e
      @errors.concat(JSONAPI::Exceptions::ParameterMissing.new(e.param, error_object_overrides).errors)
    rescue JSONAPI::Exceptions::Error => e
      e.error_object_overrides.merge! error_object_overrides
      @errors.concat(e.errors)
    end

    def setup_additional_methods(method_name, params, resource_klass)
      fields = parse_fields(resource_klass, params[:fields])
      include_directives = parse_include_directives(resource_klass, params[:include])
      filters = parse_filters(resource_klass, params[:filter])
      sort_criteria = parse_sort_criteria(resource_klass, params[:sort])
      paginator = parse_pagination(resource_klass, params[:page])
      relationship_type = params[:relationship].present? ? params[:relationship].to_sym : nil

      ## parse additional data based on requirements
      JSONAPI::Operation.new(
        method_name,
        resource_klass,
        context: context,
        filters: filters,
        include_directives: include_directives,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        relationship_type: relationship_type
      )
    end

    def parse_fields(resource_klass, fields)
      extracted_fields = {}
      if fields.nil?
        context[:only_default_attributes] = true
        return extracted_fields
      end

      # Extract the fields for each type from the fields parameters
      if fields.is_a?(ActionController::Parameters) || fields.is_a?(Hash)
        fields.each do |field, value|
          next if value.blank?
          value = value.split(',') if value.is_a? String
          value = ['__all_attributes__'] if value.include?('__all_attributes__')
          resource_fields = modify_field_values(value)
          extracted_fields[field] = resource_fields
        end
      else
        fail JSONAPI::Exceptions::InvalidFieldFormat.new(error_object_overrides)
      end

      # Validate the fields
      validated_fields = {}
      extracted_fields.each do |type, values|
        underscored_type = unformat_key(type)
        validated_fields[type] = []
        begin
          if type != format_key(type)
            fail JSONAPI::Exceptions::InvalidResource.new(type, error_object_overrides)
          end
          type_resource = Resource.resource_klass_for(resource_klass.module_path + underscored_type.to_s)
        rescue NameError
          fail JSONAPI::Exceptions::InvalidResource.new(type, error_object_overrides)
        end

        if type_resource.nil?
          fail JSONAPI::Exceptions::InvalidResource.new(type, error_object_overrides)
        else
          unless values.nil?
            valid_fields = type_resource.fields.collect { |key| format_key(key) }
            values.each do |field|
              if valid_fields.include?(field)
                validated_fields[type].push unformat_key(field)
              else
                fail JSONAPI::Exceptions::InvalidField.new(type, field, error_object_overrides)
              end
            end
          else
            fail JSONAPI::Exceptions::InvalidField.new(type, 'nil', error_object_overrides)
          end
        end
      end
      validated_fields.deep_transform_keys { |key| unformat_key(key) }
    end

    def modify_field_values(value)
      if value.include?('__all_attributes__')
        ['all_attributes']
      elsif value.include?('__additional_attributes__')
        value.delete('__additional_attributes__')
        value << 'additional_data'
      else
        value
      end
    end

    def parse_filters(resource_klass, filters)
      parsed_filters = {}

      # apply default filters
      resource_klass._allowed_filters.each do |filter, opts|
        next if opts[:default].nil? || !parsed_filters[filter].nil?
        parsed_filters[filter] = opts[:default]
      end

      return parsed_filters unless filters

      filters = extract_special_filters(filters)

      unless filters.class.method_defined?(:each)
        @errors.concat(JSONAPI::Exceptions::InvalidFiltersSyntax.new(filters).errors)
        return {}
      end

      unless JSONAPI.configuration.allow_filter
        fail JSONAPI::Exceptions::ParameterNotAllowed.new(:filter)
      end

      filters.each do |filter_type, filter_arr|
        filter_arr.each do |key, value|
          filter = unformat_key(key)
          if resource_klass._allowed_filter?(filter)
            parsed_filters[filter] = { value: value, operator: filter_type }
          else
            fail JSONAPI::Exceptions::FilterNotAllowed.new(filter)
          end
        end
      end

      parsed_filters
    end


  end
end
