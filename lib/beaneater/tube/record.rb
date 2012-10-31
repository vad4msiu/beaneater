module Beaneater
  class Tube < PoolCommand
    DEFAULT_DELAY = 0
    DEFAULT_PRIORITY = 65536 # 0 is the highest pri
    DEFAULT_TTR = 120

    attr_reader :name

    def initialize(pool, name)
      @name = name
      @mutex = Mutex.new
      super(pool)
    end

    # @beaneater_tube.put "data", :pri => 1000, :ttr => 10, :delay => 5
    def put(data, options={})
      safe_use do
        options = { :pri => DEFAULT_PRIORITY, :delay => DEFAULT_DELAY, :ttr => DEFAULT_TTR }.merge(options)
        cmd_options = "#{options[:pri]} #{options[:delay]} #{options[:ttr]} #{data.bytesize}"
        transmit_to_rand("put #{cmd_options}\n#{data}")
      end
    end

    # Accepts :ready, :delayed, :buried
    def peek(state)
      safe_use do
        res = transmit_until_res "peek-#{state}", :status => "FOUND"
        Job.new(res)
      end
    rescue Beaneater::NotFoundError => ex
      # Return nil if not found
    end

    # Reserves job from tube
    def reserve(timeout=nil, &block)
      pool.tubes.watch!(self.name)
      pool.tubes.reserve(timeout, &block)
    end

    # @beaneater_connection.tubes.kick(10)
    def kick(bounds=1)
      safe_use { transmit_to_rand("kick #{bounds}") }
    end

    # Returns stats for this tube
    def stats
      res = transmit_to_all("stats-tube #{name}", :merge => true)
      StatStruct.from_hash(res[:body])
    end

    # @beaneater_connection.tubes.find(123).pause(120)
    def pause(delay)
      transmit_to_all("pause-tube #{name} #{delay}")
    end

    def to_s
      "#<Beaneater::Tube name=#{name.inspect}>"
    end
    alias :inspect :to_s

    protected

    def safe_use(&block)
      @mutex.lock
      tubes.use(self.name)
      yield
    ensure
      @mutex.unlock
    end
  end # Tube
end # Beaneater
