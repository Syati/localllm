# frozen_string_literal: true
require "localllm/mcp/client"
# Mcp client follows the protocol
# @see https://modelcontextprotocol.io/docs/learn/architecture#data-layer-2
module Localllm
  module BraveSearch
    class McpClient < Localllm::Mcp::Client
      def exec(name:, arguments: {})
        args = arguments.dup
        if args["search_lang"] == "ja"
          args["search_lang"] = "jp"
        end
        super(name:, arguments: args)
      end

      def to_openai_functions
        @functions ||= list.map(&:to_openai_function_definition)
      end
    end
  end
end
