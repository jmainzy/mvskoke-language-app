#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "set"
require "tempfile"

class ConjugationIndex
  def initialize(action_paradigms:, stative_paradigms:, blocked_stems:, normalizer:)
    @action_paradigms = action_paradigms
    @stative_paradigms = stative_paradigms
    @blocked_stems = blocked_stems
    @normalizer = normalizer
    @index = Hash.new { |hash, key| hash[key] = Set.new }
    @candidates = Hash.new { |hash, key| hash[key] = Set.new }
    @unsupported = []
  end

  def build(source)
    sense_ids = Set.new
    File.foreach(source, encoding: "UTF-8").with_index(1) do |line, line_number|
      next if line.strip.empty?

      begin
        row = JSON.parse(line)
      rescue JSON::ParserError => error
        raise ArgumentError, "#{source}:#{line_number}: #{error.message}"
      end
      unless row.is_a?(Hash) && row["sense_id"].is_a?(String) && !row["sense_id"].empty? &&
             row["headword"].is_a?(String) && !row["headword"].empty?
        raise ArgumentError, "#{source}:#{line_number}: expected a sense_id and headword"
      end

      sense_id = row["sense_id"]
      raise ArgumentError, "#{source}:#{line_number}: duplicate sense_id #{sense_id}" unless sense_ids.add?(sense_id)

      headword = row["headword"]
      add_surface(headword, [sense_id])
      next if headword.match?(/\s/)

      normalized = @normalizer.call(headword)
      if normalized.end_with?("etv") && !@blocked_stems.include?(headword)
        @candidates[[:action, headword]].add(sense_id)
      elsif %w[adjective adj stative].include?(row["grammatical_info_id"]) && normalized.end_with?("e")
        @candidates[[:stative, headword]].add(sense_id)
      end
    end

    @candidates.each do |(verb_class, headword), ids|
      paradigms = verb_class == :action ? @action_paradigms : @stative_paradigms
      paradigms.each do |spec|
        begin
          tree = spec.fetch(:mod).new(headword).conjugate!
        rescue StandardError => error
          @unsupported << "#{headword} (#{spec.fetch(:key)}): #{error.class}: #{error.message}"
          next
        end
        raise TypeError, "#{headword} (#{spec.fetch(:key)}): expected a conjugation tree" unless tree.is_a?(Hash)

        tree.each do |person, constructions|
          next if person.to_s == "verb"
          raise TypeError, "expected constructions for #{headword} #{person}" unless constructions.is_a?(Hash)

          constructions.each_value do |leaf|
            surfaces(leaf).each do |surface|
              surface = surface.sub(/\s*\(of (?:2|3\+)\)\s*\z/i, "").strip
              next if surface.empty? || surface == "N/A"

              add_surface(surface, ids)
              add_surface(surface.split(/\s+/, 2).first, ids) if surface.match?(/\s/)
            end
          end
        end
      end
    end

    unless @unsupported.empty?
      warn "Conjugator could not generate #{@unsupported.size} paradigms:"
      @unsupported.each { |message| warn "  #{message}" }
    end
    @index.sort.to_h.transform_values { |ids| ids.to_a.sort }
  end

  private

  def surfaces(leaf)
    case leaf
    when String then [leaf]
    when Array then leaf.flat_map { |item| surfaces(item) }
    else raise TypeError, "unexpected conjugation leaf #{leaf.inspect}"
    end
  end

  def add_surface(surface, ids)
    exact = surface.unicode_normalize(:nfc).downcase.strip
    [exact, @normalizer.call(surface)].uniq.each do |key|
      @index[key].merge(ids) unless key.empty?
    end
  end
end

if $PROGRAM_NAME == __FILE__
  options = {
    source: File.join(Dir.pwd, "storage", "lexicon_search.jsonl"),
    output: File.expand_path("../assets/word_index.json", __dir__)
  }
  OptionParser.new do |parser|
    parser.banner = "Run from the Punvyvs directory with bundle exec ruby #{__FILE__} [options]"
    parser.on("--source PATH", "Lexicon JSONL (default: Punvyvs storage/lexicon_search.jsonl)") { |v| options[:source] = v }
    parser.on("--output PATH", "Output JSON (default: assets/word_index.json)") { |v| options[:output] = v }
  end.parse!
  abort "Unexpected arguments: #{ARGV.join(' ')}" unless ARGV.empty?
  environment = File.join(Dir.pwd, "config", "environment.rb")
  abort "Run this script from the Punvyvs directory using bundle exec ruby." unless File.file?(environment)
  abort "Source and output must be different files." if File.expand_path(options[:source]) == File.expand_path(options[:output])

  require environment
  index = ConjugationIndex.new(
    action_paradigms: Conjugation::Miner::ACTION_PARADIGMS,
    stative_paradigms: Conjugation::Miner::STATIVE_PARADIGMS,
    blocked_stems: Conjugation::Miner::BLOCKED_STEMS,
    normalizer: Form.method(:normalize)
  ).build(options[:source])
  Tempfile.create(["word_index", ".json"], File.dirname(File.expand_path(options[:output]))) do |file|
    file.write(JSON.generate(index), "\n")
    file.close
    File.rename(file.path, options[:output])
  end
  puts "Wrote #{index.size} lookup keys to #{options[:output]}"
end
