module JSONAPI
  class CustomResponseDocument < ResponseDocument

    def add_result(result, operation)
      if result.is_a?(JSONAPI::ErrorsOperationResult)
        # Clear any serialized results
        @serialized_results = []

        # In JSONAPI v1 we only have one operation so all errors can be kept together
        result.errors.each do |error|
          add_global_error(error)
        end
      else
        if result.is_a?(JSONAPI::OperationResult)
          @serialized_results.push result.to_hash(operation.options[:serializer])
          @result_codes.push result.code.to_i
          update_links(operation.options[:serializer], result)
          update_meta(result)
        else
          @serialized_results.push(operation.options[:serializer].serialize_generic_result(result))
        end
      end
    end

  end
end
