require 'yaml'
require 'json'

module PushyDaemon

  class ShouterResponseError    < StandardError; end
  class ShouterChannelClosed    < StandardError; end
  class ShouterPreconditionFailed    < StandardError; end
  class ShouterInterrupted      < StandardError; end
  class EndpointTopicContext    < StandardError; end

  class Shouter < Endpoint

    attr_accessor :table

    def initialize
      # Init
      super
      @keys = []

      # Start connexion to RabbitMQ and create channel
      conn = connect Conf.bus
      @channel = conn.create_channel
      info "connected on a channel"

      # Check config
      config_shout = Conf[:shout]
      if (config_shout.is_a? Enumerable) && !config_shout.empty?
        @keys = config_shout[:keys] if config_shout[:keys].is_a? Array
        @topic = config_shout[:topic]

        info "found topic: #{@topic}"
        info "found keys: #{@keys.join(', ')}"
      else
        error "prepare: empty [shout] section"
      end

      # Create exchange
      raise PushyDaemon::EndpointTopicContext unless @topic
      @exchange = @channel.topic(@topic, durable: true, persistent: true)

    rescue Bunny::TCPConnectionFailedForAllHosts => e
      error "ERROR: cannot connect to RabbitMQ hosts (#{e.inspect})"
    end

    def shout
      # Prepare exchange
      loop do
        if true # shout_exchange
          random_string = SecureRandom.hex
          random_key = @keys.sample || "random"
          channel_shout [:ping, random_key, random_string], {}
        end
        sleep 1
      end
    rescue AMQ::Protocol::EmptyResponseError => e
      raise PushyDaemon::ShouterResponseError, "#{e.class} (#{e.inspect})"
    rescue Bunny::ChannelAlreadyClosed => e
      raise PushyDaemon::ShouterChannelClosed, "#{e.class} (#{e.inspect})"
    rescue Bunny::PreconditionFailed => e
      raise PushyDaemon::ShouterPreconditionFailed, "#{e.class} (#{e.inspect})"

    rescue Interrupt => e
      @channel.close
      raise PushyDaemon::ShouterInterrupted, "#{e.class} (#{e.inspect})"
    end

  private

    def channel_shout keys, body = {}
      # Prepare headers
      headers = {
        sent_at: DateTime.now.iso8601,
        sent_by: Conf.name
        }

      # Prepare exchange_name and routing_key
      exchange_name = @exchange.name
      routing_key = keys.unshift(exchange_name).join('.')

      # Announce shout
      message way: WAY_OUT, exchange: exchange_name, key: routing_key, body: nil, attrs: {}

      # Publish
      @exchange.publish(body.to_json,
        routing_key: routing_key,
        headers: headers,
        app_id: Conf.name,
        content_type: "application/json",
        )

    end

  end
end
