class Api::V1::Chat::CompletionsController < ::ApiController
  include ActionController::Live
  before_action :set_sse_headers

  def create
    stream = Localllm::OpenAI::Client.chat.completions.stream_raw(params.permit!.to_h)
    sse = SSE.new(response.stream, retry: 300)

    begin
      stream.each { sse.write(_1) }
      # ストリームの終了を知らせる（OpenAI 仕様）
      sse.write("[DONE]")
    ensure
      sse.close
    end
  end

  private

  def set_sse_headers
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no' # nginx 対策
  end
end
