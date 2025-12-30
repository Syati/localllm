class Api::V1::Chat::CompletionsController < ::ApiController
  def create
    render json: { message: "Hello World" }
  end
end
