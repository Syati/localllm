# frozen_string_literal: true

module Localllm
  module Mcp
    module Tool
      class Function
        attr_reader :name, :title, :description, :input_schema
        def initialize(name:, title:, description:, input_schema: [])
          @name = name
          @title = title
          @description = description
          @input_schema = input_schema
        end

        def to_openai_function_definition
          {
            type: "function",
            function: {
              name: @name,
              description: @description,
              parameters: @input_schema
            }
          }
        end
      end
    end
  end
end
