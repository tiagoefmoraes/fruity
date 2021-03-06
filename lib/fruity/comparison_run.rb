# encoding: utf-8

module Fruity
  class ComparisonRun < Struct.new(:group, :timings, :baselines)
    attr_reader :stats

    # +timings+ must be an array of size `group.size` of arrays of delays
    # or of arrays of [delay, baseline]
    #
    def initialize(group, timings, baselines)
      raise ArgumentError, "Expected timings to be an array with #{group.size} elements (was #{timings.size})" unless timings.size == group.size
      super

      filter = group.options.fetch(:filter)

      baseline = Util.filter(baselines, *filter) if baseline_type == :single

      @stats = timings.map.with_index do |series, i|
        case baseline_type
        when :split
          Util.difference(Util.filter(series, *filter), Util.filter(baselines.fetch(i), *filter))
        when :single
          Util.difference(Util.filter(series, *filter), baseline)
        when :none
          Util.stats(series)
        end
      end.freeze
    end

    def to_s
      order = (0...group.size).sort_by{|i| @stats[i][:mean] }
      results = group.elements.map{|n, exec| Util.result_of(exec, group.options) }
      order.each_cons(2).map do |i, j|
        cmp = comparison(i, j)
        s = if cmp[:factor] == 1
          "%{cur} is similar to %{vs}%{different}"
        else
          "%{cur} is faster than %{vs} by %{ratio}%{different}"
        end
        s % {
          :cur => group.elements.keys[i],
          :vs => group.elements.keys[j],
          :ratio => format_comparison(cmp),
          :different => results[i] == results[j] ? "" : " (results differ: #{results[i]} vs #{results[j]})"
        }
      end.join("\n")
    end

    def export(fn = (require "tmpdir"; "#{Dir.tmpdir}/export.csv"))
      require "csv"
      CSV.open(fn, "wb") do |csv|
        head = group.elements.keys
        case baseline_type
        when :split
          head = head.flat_map{|h| [h, "#{head} bl"]}
          data = timings.zip(baselines).flatten(1).transpose
        when :single
          data = (timings + [baselines]).transpose
          head << "baseline"
        else
          data = timings.transpose
        end
        csv << head
        data.each{|vals| csv << vals}
      end
      fn
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

    def baseline_type
      if baselines.nil?
        :none
      elsif baselines.first.is_a?(Array)
        :split
      else
        :single
      end
    end
  end
end
