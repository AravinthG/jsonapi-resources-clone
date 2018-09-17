module JSONAPI
  class CustomResourceSerializer < ResourceSerializer

    def serialize_generic_result result
      {data: result}
    end

    private

    # overriding the attributes_hash implementation from base ResourceSerializer
    def attributes_hash(source, fetchable_fields)
      fields = fetchable_fields & supplying_attribute_fields(source.class)
      response =  fields.each_with_object({}) do |name, hash|
                    format = source.class._attribute_options(name)[:format]
                    res = format_value(source.public_send(name), format)
                    if name == :additional_data || name == :all_attributes
                      hash.merge!(res)
                    else
                      hash[format_key(name)] = res
                    end
                  end

      response = source.format_response(response, fields) if source.class.has_custom_format?
      response
    end

  end
end
