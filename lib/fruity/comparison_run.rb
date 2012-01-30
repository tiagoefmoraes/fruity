# encoding: utf-8

module Fruity
  class ComparisonRun < Struct.new(:group, :timings)
    attr_reader :stats

    # +timings+ must be an array of size `group.size` of arrays of delays
    # or of arrays of [delay, baseline]
    #
    def initialize(group, timings)
      raise ArgumentError, "Expected timings to be an array with #{group.size} elements (was #{timings.size})" unless timings.size == group.size
      super
      @stats = timings.map do |series|
        time, baseline = series.first
        if baseline
          Util.difference(*series.transpose.map{|s| Util.filter(s, *group.options.fetch(:filter))})
        else
          Util.stats(series)
        end
      end.freeze
    end

    def to_s
      order = (0...group.size).sort_by{|i| @stats[i][:mean] }
      order.each_cons(2).map do |i, j|
        cmp = comparison(i, j)
        s = if cmp[:factor] == 1
          "%{cur} is similar to %{vs}"
        else
          "%{cur} is faster than %{vs} by %{ratio}"
        end
        s % {
          :cur => group.elements.keys[i],
          :vs => group.elements.keys[j],
          :ratio => format_comparison(cmp),
        }
      end.join("\n")
    end

    def size
      timings.first.size
    end

    def factor(cur = 0, vs = 1)
      comparison(cur, vs)[:factor]
    end

    def factor_range(cur = 0, vs =1)
      comparison(cur, vs)[:min]..comparison(cur, vs)[:max]
    end

    def comparison(cur = 0, vs = 1)
      Util.compare_stats(@stats[cur], @stats[vs])
    end

    def format_comparison(cmp)
      ratio = cmp[:factor]
      prec = cmp[:precision]
      if ratio.abs > 1.8
        "#{ratio}x ± #{prec}"
      else
        "#{(ratio - 1)*100}% ± #{prec*100}%"
      end
    end
  end
end
