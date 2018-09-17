module JSONAPI
  module FilterHelper

    OPERATORS = {
      like: 'like',
      not_like: 'not like',
      gt:  '>',
      lt:  '<',
      gte: '>=',
      lte: '<='
    }

    def extract_special_filters filters
      std_filters = filters.slice!(:not, :like, :not_like, :gt, :gte, :lt, :lte)
      filters.merge!({std: std_filters})
    end

    def parse_filter_keys(filters, resource_klass, params)
      resource_klass.get_custom_formatter_class.constantize.format_filter(filters, params)
    end

    def filter_query_string(field_name, value)
      case value[:operator].to_sym
      when :not
        if value[:value].is_a?(Array)
          "#{field_name} not in ('#{value[:value].join("','")}')"
        else
          "#{field_name} != '#{value[:value]}'"
        end
      when :like, :not_like
        op = OPERATORS[value[:operator].to_sym]
        if value[:value].is_a? Array
          value[:value].map {|regex| "#{field_name} #{op} '#{regex}'"}.join(" or ")
        else
          "#{field_name} #{op} '#{value[:value]}'"
        end
      when :gt, :lt, :gte, :lte
        op = OPERATORS[value[:operator].to_sym]
        val = value[:value].is_a?(Array) ? value[:value].first : value[:value]
        "#{field_name} #{op} '#{val}'"
      else
        raise 'Invalid op'
      end
    end

  end
end
