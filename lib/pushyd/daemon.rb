module PushyDaemon
  class Daemon

    def self.run
      # Create a new proxy
      p = Proxy.new

      # Dump config table
      puts p.table.to_s

      # Create a new shouter
      s = Shouter.new

      # Start shout loop
      s.shout

      # Backup infinite loop in case shout does nothing
      loop do
      end

    rescue Errno::EACCES, StandardError => e
      abort "EXITING #{e.class}: #{e.message} \n #{e.backtrace.inspect}"
    end

  end
end
