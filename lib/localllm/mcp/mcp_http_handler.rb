module Localllm
  module Mcp

    class McpHttpHandler < Faraday::Middleware

      def initialize(app)
        super(app)
        @session_id = nil
      end

      def call(env)
        # 1. リクエスト前の共通処理
        env[:request_headers]['Accept'] = 'application/json, text/event-stream'
        env[:request_headers]['mcp-session-id'] = @session_id if @session_id

        @app.call(env).on_complete do |response_env|
          # 2. セッションIDの自動抽出
          sid = response_env[:response_headers]['mcp-session-id']
          @session_id = sid if sid

          # 3. SSE形式のボディをJSONに変換
          if response_env[:response_headers]['content-type']&.include?('text/event-stream')
            parse_sse_body(response_env)
          end
        end
      end

      private

      def parse_sse_body(env)
        return if env[:body].nil? || env[:body].is_a?(Hash)

        # body が String であることを保証し、安全に処理する
        body_str = env[:body].to_s
        if body_str =~ /data: (\{.*\})/
          begin
            env[:body] = JSON.parse($1)
          rescue JSON::ParserError => e
            Rails.logger.error "MCP JSON Parse Error: #{e.message}"
          end
        end
      end
    end
  end
end
