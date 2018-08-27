module JSONAPI
  class CustomResourceSerializer < ResourceSerializer

    def serialize_generic_result result
      {data: result}
    end

    private

    # overriding the attributes_hash implementation from base ResourceSerializer
    def attributes_hash(source, fetchable_fields)
      fields = fetchable_fields & supplying_attribute_fields(source.class)
      fields.each_with_object({}) do |name, hash|
        unless name == :id
          format = source.class._attribute_options(name)[:format]
          res = format_value(source.public_send(name), format)
          if name == :additional_data || name == :all_attributes
            hash.merge!(res)
          else
            hash[format_key(name)] = res
          end
        end
      end
    end

  end
end
