module Ferryman
  class Client
    def initialize(redis, channel)
      @redis = redis
      @channel = channel
    end

    def cast(method, *arguments)
      message = JsonRpcObjects::V20::Request.create(method, arguments).to_json
      @redis.publish(@channel, message)
    end

    def call(method, *arguments)
      multicall(method, *arguments).first
    end

    def multicall(method, *arguments)
      key = random_key
      message = JsonRpcObjects::V20::Request.create(method, arguments, id: key).to_json
      servers_count = @redis.publish(@channel, message)
      servers_count.to_i.times.map do
        raw_response = @redis.blpop(key).last
        response = JsonRpcObjects::Response.parse(raw_response)
        response.result || raise(Ferryman::Error.new(response.error))
      end
    end

    private

    def random_key
      SecureRandom.hex(16)[0..7]
    end
  end
end