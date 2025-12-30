# frozen_string_literal: true
module Localllm
  module OpenAI
    class Client
      THREAD_KEY = :localllm_openai_client

      class << self
        delegate_missing_to :instance

        def configure
          yield config if block_given?
          reset_all_threads!
        end

        def config
          @config ||= Struct.new(:api_key, :organization, :project, :webhook_secret, :base_url, :max_retries, :timeout, :initial_retry_delay, :max_retry_delay).new
        end

        def instance
          Thread.current[THREAD_KEY] ||= build_client
        end

        def reset!
          Thread.current[THREAD_KEY] = nil
        end

        private

        def build_client
          ::OpenAI::Client.new(
            api_key: config.api_key,
            organization: config.organization,
            project: config.project,
            webhook_secret: config.webhook_secret,
            base_url: config.base_url,
            max_retries: config.max_retries || ::OpenAI::Client::DEFAULT_MAX_RETRIES,
            timeout: config.timeout || ::OpenAI::Client::DEFAULT_TIMEOUT_IN_SECONDS,
            initial_retry_delay: config.initial_retry_delay || ::OpenAI::Client::DEFAULT_INITIAL_RETRY_DELAY,
            max_retry_delay: config.max_retry_delay || ::OpenAI::Client::DEFAULT_MAX_RETRY_DELAY
          )
        end

        def reset_all_threads!
          Thread.list.each { |t| t[THREAD_KEY] = nil if t.alive? rescue nil }
        end
      end
    end
  end
end
