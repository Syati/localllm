class Api::V1::Chat::CompletionsController < ::ApiController
  include ActionController::Live

  def create
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no' # nginx 対策

    stream = Localllm::OpenAI::Client.chat.completions.stream_raw(params.permit!.to_h)

    begin
      stream.each do |event|
        response.stream.write("data: #{event.to_json}\n\n")
      end

      # ストリームの終了を知らせる（OpenAI 仕様）
      response.stream.write("data: [DONE]\n\n")
    ensure
      response.stream.close
    end
  end
end
