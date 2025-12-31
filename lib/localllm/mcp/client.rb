# frozen_string_literal: true

# Mcp client follows the protocol
# @see https://modelcontextprotocol.io/docs/learn/architecture#data-layer-2
module Localllm
  module Mcp
    class Client
      THREAD_KEY = :mcp_client
      ID_KEY = :mcp_request_id
      STARTED_KEY = :mcp_request_started

      class << self
        delegate_missing_to :instance

        def configure
          yield config if block_given?
          reset_all_threads!
        end

        def config
          @config ||= Struct.new(:base_url).new
        end

        def instance
          Thread.current[THREAD_KEY] ||= build_client
        end

        def reset!
          Thread.current[THREAD_KEY] = nil
          Thread.current[ID_KEY] = nil
          Thread.current[STARTED_KEY] = nil
        end

        private

        def build_client
          Faraday.new(url: config.base_url) do |f|
            f.request :json
            f.response :json
            f.use McpHttpHandler
            f.response :raise_error
            f.response :logger, Rails.logger, bodies: true, log_level: :debug
            f.adapter Faraday.default_adapter
          end
        end

        def reset_all_threads!
          Thread.list.each do |t|
            begin
              if t.alive?
                t[THREAD_KEY] = nil
                t[ID_KEY] = nil
                t[STARTED_KEY] = nil
              end
            rescue StandardError
              nil
            end
          end
        end
      end

      def list
        ensure_started
        tools = call_method("tools/list").body.dig("result", "tools") || []
        tools.map do |tool|
          Tool::Function.new(
            name: tool["name"],
            title: tool["title"],
            description: tool["description"],
            input_schema: tool["inputSchema"]
          )
        end
      end

      def exec(name:, arguments: {})
        ensure_started
        payload = {
          name: name,
          arguments: arguments
        }
        call_method("tools/call", payload)
      end

      private

      def ensure_started
        return if Thread.current[STARTED_KEY]

        start
      end

      def start
        params = {
          protocolVersion: "2025-06-18",
          capabilities: {},
          clientInfo: {
            name: "Localllm",
            version: "1.0.0"
          } }
        call_method("initialize", params)
        Thread.current[STARTED_KEY] = true
      end


      def call_method(method, params = {})
        payload = {
          jsonrpc: "2.0",
          id: next_id, # ここでインクリメント
          method: method,
          params: params
        }
        client.post('', payload)
      end

      def client
        self.class.instance
      end

      def next_id
        Thread.current[ID_KEY] ||= 0
        Thread.current[ID_KEY] += 1
      end
    end
  end
end
